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
	"time"

	"github.com/DefinedNet/dnapi"
	"github.com/DefinedNet/dnapi/keys"
	"github.com/DefinedNet/dnapi/message"
	"github.com/sirupsen/logrus"
	"github.com/slackhq/nebula/cert"
)

type APIClient struct {
	c *dnapi.Client
	l *logrus.Logger
}

type EnrollResult struct {
	Site string
}

type TryUpdateResult struct {
	FetchedUpdate bool
	Site          string
}

func NewAPIClient(useragent string) *APIClient {
	// TODO Use a log file
	l := logrus.New()
	l.SetOutput(io.Discard)

	return &APIClient{
		// TODO Make the server configurable
		c: dnapi.NewClient(useragent, "https://api.defined.net"),
		l: l,
	}
}

type InvalidCredentialsError struct{}

func (e InvalidCredentialsError) Error() string {
	// XXX Type information is not available in Kotlin/Swift. Instead we make use of string matching on the error
	// message. DO NOT CHANGE THIS STRING unless you also update the Kotlin and Swift code that checks for it.
	return "invalid credentials"
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

	site, err := newDNSite(meta.Org.Name, cfg, string(pkey), *creds)
	if err != nil {
		return nil, fmt.Errorf("failure generating site: %s", err)
	}

	jsonSite, err := json.Marshal(site)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal site: %s", err)
	}

	return &EnrollResult{Site: string(jsonSite)}, nil
}

func (c *APIClient) TryUpdate(siteName string, hostID string, privateKey string, counter int, trustedKeys string) (*TryUpdateResult, error) {
	// Build dnapi.Credentials struct from inputs
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

	creds := keys.Credentials{
		HostID:      hostID,
		PrivateKey:  pk,
		Counter:     uint(counter),
		TrustedKeys: tk,
	}

	// Check for update
	msg, err := c.c.LongPollWait(context.Background(), creds, []string{message.DoUpdate})
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
	default:
		return &TryUpdateResult{FetchedUpdate: false}, nil
	}
}

func (c *APIClient) doUpdate(siteName string, creds keys.Credentials) (*TryUpdateResult, error) {
	// Perform the update and return the new site object
	updateCtx, updateCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer updateCancel()
	cfg, pkey, newCreds, _, err := c.c.DoUpdate(updateCtx, creds)
	switch {
	case errors.Is(err, dnapi.ErrInvalidCredentials):
		return nil, InvalidCredentialsError{}
	case err != nil:
		return nil, fmt.Errorf("DoUpdate error: %s", err)
	}

	site, err := newDNSite(siteName, cfg, string(pkey), *newCreds)
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
