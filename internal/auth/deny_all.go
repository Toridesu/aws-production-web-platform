package auth

import "context"

// DenyAllVerifier is used by the Phase 5 ECS deployment until real token
// verification is implemented. It keeps health checks public while rejecting
// every authenticated API request.
type DenyAllVerifier struct{}

func (DenyAllVerifier) Verify(_ context.Context, _ string) (Principal, error) {
	return Principal{}, ErrInvalidToken
}
