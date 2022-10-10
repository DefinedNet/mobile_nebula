package mobileNebula

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/DefinedNet/dnapi"
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
	cfg, pkey, creds, meta, err := c.c.EnrollWithTimeout(context.Background(), 30*time.Second, c.l, code)
	var apiError *dnapi.APIError
	switch {
	case errors.As(err, &apiError):
		return nil, fmt.Errorf("%s (request ID: %s)", apiError, apiError.ReqID)
	case errors.Is(err, context.DeadlineExceeded):
		return nil, fmt.Errorf("enrollment request timed out - try again?")
	case err != nil:
		return nil, fmt.Errorf("unexpected failure: %s", err)
	}

	site, err := newDNSite(meta.OrganizationName, cfg, string(pkey), *creds)
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

	credsPkey, rest, err := cert.UnmarshalEd25519PrivateKey([]byte(privateKey))
	switch {
	case err != nil:
		return nil, fmt.Errorf("invalid private key: %s", err)
	case len(rest) > 0:
		return nil, fmt.Errorf("invalid private key: %d trailing bytes", len(rest))
	}

	keys, err := dnapi.Ed25519PublicKeysFromPEM([]byte(trustedKeys))
	if err != nil {
		return nil, fmt.Errorf("invalid trusted keys: %s", err)
	}

	creds := dnapi.Credentials{
		HostID:      hostID,
		PrivateKey:  credsPkey,
		Counter:     uint(counter),
		TrustedKeys: keys,
	}

	// Check for update
	updateAvailable, err := c.c.CheckForUpdateWithTimeout(context.Background(), 10*time.Second, creds)
	switch {
	case errors.As(err, &dnapi.InvalidCredentialsError{}):
		return nil, InvalidCredentialsError{}
	case err != nil:
		return nil, fmt.Errorf("CheckForUpdate error: %s", err)
	}

	if !updateAvailable {
		return &TryUpdateResult{FetchedUpdate: false}, nil
	}

	// Perform the update and return the new site object
	cfg, pkey, newCreds, err := c.c.DoUpdateWithTimeout(context.Background(), 10*time.Second, creds)
	switch {
	case errors.As(err, &dnapi.InvalidCredentialsError{}):
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
