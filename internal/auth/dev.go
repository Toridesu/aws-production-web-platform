package auth

import (
	"context"
	"strings"
)

// DevVerifier is only for local development. The Cognito verifier added later
// will implement the same Verifier interface.
type DevVerifier struct{}

func (DevVerifier) Verify(_ context.Context, token string) (Principal, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return Principal{}, ErrInvalidToken
	}

	parts := strings.SplitN(token, "|", 2)
	subject := strings.TrimSpace(parts[0])
	if subject == "" {
		return Principal{}, ErrInvalidToken
	}

	scopes := map[string]struct{}{
		"tasks.read":  {},
		"tasks.write": {},
	}
	if len(parts) == 2 {
		scopes = make(map[string]struct{})
		for _, scope := range strings.Split(parts[1], ",") {
			scope = strings.TrimSpace(scope)
			if scope != "" {
				scopes[scope] = struct{}{}
			}
		}
	}

	return Principal{Subject: subject, Scopes: scopes}, nil
}
