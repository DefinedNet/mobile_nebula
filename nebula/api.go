package mobileNebula

import (
	"context"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"time"

	"github.com/DefinedNet/dnapi"
	"github.com/DefinedNet/dnapi/keys"
	"github.com/DefinedNet/dnapi/message"
	"github.com/slackhq/nebula/cert"
)

type APIClient struct {
	c *dnapi.Client
	l *slog.Logger
}

type EnrollResult struct {
	Site string
}

type TryUpdateResult struct {
	FetchedUpdate bool
	Site          string
}

// PreAuthResult is returned to the platform side to start an OIDC login: open
// LoginURL in a browser, then poll EndpointAuthPoll with PollToken until COMPLETED.
type PreAuthResult struct {
	PollToken string
	LoginURL  string
}

// PollDataResult mirrors dnapi's EndpointAuthPollData. Status is one of
// WAITING, STARTED, COMPLETED; EnrollmentCode is only set once COMPLETED and is
// single-use, so the platform side must enroll with it immediately.
type PollDataResult struct {
	Status         string
	EnrollmentCode string
}

// PollDataV2Result mirrors dnapi's EndpointAuthPollDataV2. Status is one of WAITING, STARTED,
// COMPLETED. AuthToken is only set once COMPLETED; it is an endpoint OIDC user session token used to
// authenticate the host-management calls below (ListEndpointHosts/CreateEndpointHost/RenewEndpointHost).
type PollDataV2Result struct {
	Status    string
	AuthToken string
}

// EnrollCodeResult carries a host ID and a single-use enrollment code returned by
// CreateEndpointHost. Pass EnrollmentCode to Enroll immediately.
type EnrollCodeResult struct {
	HostID         string
	EnrollmentCode string
}

// NewAPIClient returns a client that talks to the production API.
func NewAPIClient(useragent string) *APIClient {
	return NewAPIClientWithServer(useragent, "https://api.defined.net")
}

// NewAPIClientWithServer returns a client that talks to the API at serverURL (scheme included),
// e.g. a staging deployment.
func NewAPIClientWithServer(useragent string, serverURL string) *APIClient {
	// TODO Use a log file
	l := slog.New(slog.NewTextHandler(io.Discard, nil))

	return &APIClient{
		c: dnapi.NewClient(useragent, serverURL),
		l: l,
	}
}

type InvalidCredentialsError struct{}

func (e InvalidCredentialsError) Error() string {
	// XXX Type information is not available in Kotlin/Swift. Instead we make use of string matching on the error
	// message. DO NOT CHANGE THIS STRING unless you also update the Kotlin and Swift code that checks for it.
	return "invalid credentials"
}

// EndpointPreAuth starts an OIDC login flow. It returns a poll token and a
// login URL; the platform side opens the URL in a browser (Custom Tab) and then
// polls EndpointAuthPoll with the token until the login completes.
func (c *APIClient) EndpointPreAuth() (*PreAuthResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	msg, err := c.c.EndpointPreAuth(ctx)
	var apiError *dnapi.APIError
	switch {
	case errors.As(err, &apiError):
		return nil, fmt.Errorf("%s (request ID: %s)", apiError, apiError.ReqID)
	case errors.Is(err, context.DeadlineExceeded):
		return nil, fmt.Errorf("request timed out - try again?")
	case err != nil:
		return nil, fmt.Errorf("unexpected failure: %s", err)
	}

	return &PreAuthResult{PollToken: msg.PollToken, LoginURL: msg.LoginURL}, nil
}

// EndpointAuthPoll checks the status of an in-progress OIDC login. The server
// long-polls (~60s) so this call may block. On COMPLETED the returned
// EnrollmentCode should be passed to Enroll immediately, as it is single-use.
func (c *APIClient) EndpointAuthPoll(pollToken string) (*PollDataResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	msg, err := c.c.EndpointAuthPoll(ctx, pollToken)
	var apiError *dnapi.APIError
	switch {
	case errors.As(err, &apiError):
		return nil, fmt.Errorf("%s (request ID: %s)", apiError, apiError.ReqID)
	case errors.Is(err, context.DeadlineExceeded):
		return nil, fmt.Errorf("request timed out - try again?")
	case err != nil:
		return nil, fmt.Errorf("unexpected failure: %s", err)
	}

	return &PollDataResult{Status: string(msg.Status), EnrollmentCode: msg.EnrollmentCode}, nil
}

// Reauthenticate renews an already-enrolled OIDC host in place. It is a signed
// call using the host's own credentials, so the server renews THIS host (extends
// its session) instead of creating a new one. Returns a login URL to open in a
// browser; after the user signs in, the refreshed config arrives via TryUpdate.
func (c *APIClient) Reauthenticate(hostID string, privateKey string, counter int, trustedKeys string) (string, error) {
	creds, err := credsFromInputs(hostID, privateKey, counter, trustedKeys)
	if err != nil {
		return "", err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	resp, err := c.c.Reauthenticate(ctx, *creds)
	switch {
	case errors.Is(err, dnapi.ErrInvalidCredentials):
		return "", InvalidCredentialsError{}
	case err != nil:
		return "", fmt.Errorf("reauthenticate error: %s", err)
	}

	return resp.LoginURL, nil
}

// apiCallErr normalizes a dnapi call error into a platform-facing message, or nil if there was no
// error. timeoutMsg is used when the call timed out.
func apiCallErr(err error, timeoutMsg string) error {
	var apiError *dnapi.APIError
	switch {
	case errors.As(err, &apiError):
		return fmt.Errorf("%s (request ID: %s)", apiError, apiError.ReqID)
	case errors.Is(err, context.DeadlineExceeded):
		return errors.New(timeoutMsg)
	case err != nil:
		return fmt.Errorf("unexpected failure: %s", err)
	}
	return nil
}

// EndpointPreAuthV2 starts a v2 (token flow) OIDC login. Like EndpointPreAuth it returns a poll
// token and login URL; unlike v1, polling with EndpointAuthPollV2 yields a session AuthToken rather
// than an enrollment code, letting the caller decide whether to create a new host or re-enroll one.
func (c *APIClient) EndpointPreAuthV2() (*PreAuthResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	msg, err := c.c.EndpointPreAuthV2(ctx)
	if e := apiCallErr(err, "request timed out - try again?"); e != nil {
		return nil, e
	}
	return &PreAuthResult{PollToken: msg.PollToken, LoginURL: msg.LoginURL}, nil
}

// EndpointAuthPollV2 checks the status of an in-progress v2 login. The server long-polls (~60s) so
// this may block. On COMPLETED the returned AuthToken authenticates the host-management calls.
func (c *APIClient) EndpointAuthPollV2(pollToken string) (*PollDataV2Result, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	msg, err := c.c.EndpointAuthPollV2(ctx, pollToken)
	if e := apiCallErr(err, "request timed out - try again?"); e != nil {
		return nil, e
	}
	return &PollDataV2Result{Status: string(msg.Status), AuthToken: msg.AuthToken}, nil
}

// ListEndpointHosts returns, as a JSON array, the hosts owned by the authenticated endpoint OIDC
// user. gomobile cannot return slices of structs, so the platform side parses the JSON. authToken
// comes from EndpointAuthPollV2.
func (c *APIClient) ListEndpointHosts(authToken string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	msg, err := c.c.ListEndpointHosts(ctx, authToken)
	if e := apiCallErr(err, "request timed out - try again?"); e != nil {
		return "", e
	}
	b, err := json.Marshal(msg.Hosts)
	if err != nil {
		return "", fmt.Errorf("failed to marshal hosts: %s", err)
	}
	return string(b), nil
}

// CreateEndpointHost creates a new host for the authenticated endpoint OIDC user and returns an
// enrollment code to redeem via Enroll. This is the explicit "add a new device" action.
func (c *APIClient) CreateEndpointHost(authToken string) (*EnrollCodeResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	msg, err := c.c.CreateEndpointHost(ctx, authToken)
	if e := apiCallErr(err, "request timed out - try again?"); e != nil {
		return nil, e
	}
	return &EnrollCodeResult{HostID: msg.HostID, EnrollmentCode: msg.EnrollmentCode}, nil
}

// RenewEndpointHost grants an existing host owned by the authenticated endpoint OIDC user a fresh
// network-access window and queues an update for it. No enrollment code is issued — the server
// never overwrites the host's key — so the platform side must run the site's normal update flow
// (TryUpdate) afterwards to fetch the renewed certificate and config with the host's own key.
func (c *APIClient) RenewEndpointHost(authToken string, hostID string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_, err := c.c.RenewEndpointHost(ctx, authToken, hostID)
	return apiCallErr(err, "request timed out - try again?")
}

func (c *APIClient) Enroll(code string) (*EnrollResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	cfg, pkey, creds, meta, err := c.c.Enroll(ctx, c.l, code)
	var apiError *dnapi.APIError
	switch {
	case errors.As(err, &apiError):
		return nil, fmt.Errorf("%s (request ID: %s)", apiError, apiError.ReqID)
	case errors.Is(err, context.DeadlineExceeded):
		return nil, fmt.Errorf("enrollment request timed out - try again?")
	case err != nil:
		return nil, fmt.Errorf("unexpected failure: %s", err)
	}

	site, err := newDNSite(meta.Org.Name, cfg, string(pkey), *creds, meta)
	if err != nil {
		return nil, fmt.Errorf("failure generating site: %s", err)
	}

	jsonSite, err := json.Marshal(site)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal site: %s", err)
	}

	return &EnrollResult{Site: string(jsonSite)}, nil
}

// credsFromInputs rebuilds a dnapi credentials struct from the fields the
// platform side persists for a managed site.
func credsFromInputs(hostID string, privateKey string, counter int, trustedKeys string) (*keys.Credentials, error) {
	if counter < 0 {
		return nil, fmt.Errorf("invalid counter value: must be unsigned")
	}

	pk, rest, err := unmarshalHostPrivateKey([]byte(privateKey))
	switch {
	case err != nil:
		return nil, fmt.Errorf("invalid private key: %s", err)
	case len(rest) > 0:
		return nil, fmt.Errorf("invalid private key: %d trailing bytes", len(rest))
	}

	tk, err := keys.TrustedKeysFromPEM([]byte(trustedKeys))
	if err != nil {
		return nil, fmt.Errorf("invalid trusted keys: %s", err)
	}

	return &keys.Credentials{
		HostID:      hostID,
		PrivateKey:  pk,
		Counter:     uint(counter),
		TrustedKeys: tk,
	}, nil
}

func (c *APIClient) TryUpdate(siteName string, hostID string, privateKey string, counter int, trustedKeys string, nebulaCert string, nebulaKey string) (*TryUpdateResult, error) {
	credsPtr, err := credsFromInputs(hostID, privateKey, counter, trustedKeys)
	if err != nil {
		return nil, err
	}
	creds := *credsPtr

	// Check for update
	msg, err := c.c.LongPollWait(context.Background(), creds, []string{message.DoUpdate, message.DoConfigUpdate})
	switch {
	case errors.Is(err, dnapi.ErrInvalidCredentials):
		return nil, InvalidCredentialsError{}
	case err != nil:
		return nil, fmt.Errorf("LongPollWait error: %s", err)
	}
	var msgType struct{ Command string }
	err = json.Unmarshal(msg.Action, &msgType)
	if err != nil {
		return nil, fmt.Errorf("failed to parse LongPollWait response: %s", err)
	}
	switch msgType.Command {
	case message.DoUpdate:
		return c.doUpdate(siteName, creds)
	case message.DoConfigUpdate:
		return c.doConfigUpdate(siteName, creds, nebulaCert, nebulaKey)
	default:
		return &TryUpdateResult{FetchedUpdate: false}, nil
	}
}

func (c *APIClient) doUpdate(siteName string, creds keys.Credentials) (*TryUpdateResult, error) {
	// Perform the update and return the new site object
	updateCtx, updateCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer updateCancel()
	cfg, pkey, newCreds, meta, err := c.c.DoUpdate(updateCtx, creds)
	switch {
	case errors.Is(err, dnapi.ErrInvalidCredentials):
		return nil, InvalidCredentialsError{}
	case err != nil:
		return nil, fmt.Errorf("DoUpdate error: %s", err)
	}

	site, err := newDNSite(siteName, cfg, string(pkey), *newCreds, meta)
	if err != nil {
		return nil, fmt.Errorf("failure generating site: %s", err)
	}

	jsonSite, err := json.Marshal(site)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal site: %s", err)
	}

	return &TryUpdateResult{Site: string(jsonSite), FetchedUpdate: true}, nil
}

func (c *APIClient) doConfigUpdate(siteName string, creds keys.Credentials, nebulaCert, nebulaKey string) (*TryUpdateResult, error) {
	updateCtx, updateCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer updateCancel()
	cfg, newCreds, meta, err := c.c.DoConfigUpdate(updateCtx, creds)
	switch {
	case errors.Is(err, dnapi.ErrInvalidCredentials):
		return nil, InvalidCredentialsError{}
	case err != nil:
		return nil, fmt.Errorf("DoConfigUpdate error: %s", err)
	}

	// DoConfigUpdate returns config without the cert, so insert the existing one
	cfg, err = dnapi.InsertConfigCert(cfg, []byte(nebulaCert))
	if err != nil {
		return nil, fmt.Errorf("failed to insert cert into config: %s", err)
	}

	site, err := newDNSite(siteName, cfg, nebulaKey, *newCreds, meta)
	if err != nil {
		return nil, fmt.Errorf("failure generating site: %s", err)
	}

	jsonSite, err := json.Marshal(site)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal site: %s", err)
	}

	return &TryUpdateResult{Site: string(jsonSite), FetchedUpdate: true}, nil
}

func unmarshalHostPrivateKey(b []byte) (keys.PrivateKey, []byte, error) {
	k, r, err := keys.UnmarshalHostPrivateKey(b)
	if err != nil {
		// We used to use a Nebula PEM header for these keys, so try that as a fallback
		k, r, c, err := cert.UnmarshalSigningPrivateKeyFromPEM(b)
		if err != nil {
			return nil, r, fmt.Errorf("failed fallback unmarshal: %w", err)
		}

		var rk any
		switch c {
		case cert.Curve_CURVE25519:
			rk = ed25519.PrivateKey(k)
		case cert.Curve_P256:
			rk, err = ecdsa.ParseRawPrivateKey(elliptic.P256(), k)
			if err != nil {
				return nil, r, fmt.Errorf("failed to parse P256 private key: %s", err)
			}
		default:
			return nil, r, fmt.Errorf("unsupported private key type: %s", c.String())
		}

		pk, err := keys.NewPrivateKey(rk)
		if err != nil {
			return nil, r, err
		}

		return pk, r, nil
	}

	return k, r, nil
}
