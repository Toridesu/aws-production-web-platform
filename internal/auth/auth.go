package auth

import (
	"context"
	"errors"
)

var ErrInvalidToken = errors.New("invalid token")

type Principal struct {
	Subject string
	Scopes  map[string]struct{}
}

func (p Principal) HasScope(scope string) bool {
	_, ok := p.Scopes[scope]
	return ok
}

type Verifier interface {
	Verify(ctx context.Context, token string) (Principal, error)
}

type principalContextKey struct{}

func WithPrincipal(ctx context.Context, principal Principal) context.Context {
	return context.WithValue(ctx, principalContextKey{}, principal)
}

func PrincipalFromContext(ctx context.Context) (Principal, bool) {
	principal, ok := ctx.Value(principalContextKey{}).(Principal)
	return principal, ok
}
