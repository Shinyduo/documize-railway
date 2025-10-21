# ---------- Frontend (Ember) ----------
# Use Node 18 to avoid OpenSSL/webpack v4 issues on Node 20+
FROM node:18-alpine AS frontbuilder
WORKDIR /go/src/github.com/documize/community/gui
COPY ./gui ./
# Enable legacy OpenSSL provider for older webpack stacks
ENV NODE_OPTIONS=--openssl-legacy-provider
# Prefer lockfile if it's in sync, otherwise fall back
RUN npm --version && (npm ci --no-audit --no-fund || npm install)
RUN npm run build -- --environment=production --output-path dist-prod --suppress-sizes true

# ---------- Backend (Go) ----------
FROM golang:1.25-alpine AS builder
WORKDIR /go/src/github.com/documize/community
COPY . .
# bring in built frontend (paths match the original repo layout)
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/assets       ./edition/static/public/assets
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/codemirror   ./edition/static/public/codemirror
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/prism        ./edition/static/public/prism
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/sections     ./edition/static/public/sections
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/tinymce      ./edition/static/public/tinymce
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/pdfjs        ./edition/static/public/pdfjs
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/i18n         ./edition/static/public/i18n
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/*.*          ./edition/static/
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/dist-prod/i18n/*.json  ./edition/static/i18n/

# static assets/templates
COPY domain/mail/*.html                          ./edition/static/mail/
COPY core/database/templates/*.html              ./edition/static/
COPY core/database/scripts/mysql/*.sql           ./edition/static/scripts/mysql/
COPY core/database/scripts/postgresql/*.sql      ./edition/static/scripts/postgresql/
COPY core/database/scripts/sqlserver/*.sql       ./edition/static/scripts/sqlserver/
COPY domain/onboard/*.json                       ./edition/static/onboard/

# build
ENV CGO_ENABLED=0 \
    GOFLAGS="-trimpath" \
    GOTOOLCHAIN=auto
RUN env GODEBUG=tls13=1 go build -mod=vendor -o bin/documize-community ./edition/community.go

# ---------- Runtime ----------
FROM alpine:3.16
RUN apk add --no-cache ca-certificates
COPY --from=builder /go/src/github.com/documize/community/bin/documize-community /documize
EXPOSE 5001
ENTRYPOINT ["/documize"]
