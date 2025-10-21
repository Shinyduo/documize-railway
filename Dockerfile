# ---------- Frontend (Ember) ----------
FROM node:20-alpine AS frontbuilder
WORKDIR /go/src/github.com/documize/community/gui
COPY ./gui ./gui
WORKDIR /go/src/github.com/documize/community/gui/gui
# Optional: cache npm
RUN npm --version && npm ci --no-audit --no-fund || npm install
RUN npm run build -- --environment=production --output-path dist-prod --suppress-sizes true

# ---------- Backend (Go) ----------
FROM golang:1.25-alpine AS builder
WORKDIR /go/src/github.com/documize/community
COPY . .
# bring in built frontend
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/assets       ./edition/static/public/assets
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/codemirror   ./edition/static/public/codemirror
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/prism        ./edition/static/public/prism
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/sections     ./edition/static/public/sections
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/tinymce      ./edition/static/public/tinymce
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/pdfjs        ./edition/static/public/pdfjs
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/i18n         ./edition/static/public/i18n
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/*.*          ./edition/static/
COPY --from=frontbuilder /go/src/github.com/documize/community/gui/gui/dist-prod/i18n/*.json  ./edition/static/i18n/

# static assets/templates
COPY domain/mail/*.html                          ./edition/static/mail/
COPY core/database/templates/*.html              ./edition/static/
COPY core/database/scripts/mysql/*.sql           ./edition/static/scripts/mysql/
COPY core/database/scripts/postgresql/*.sql      ./edition/static/scripts/postgresql/
COPY core/database/scripts/sqlserver/*.sql       ./edition/static/scripts/sqlserver/
COPY domain/onboard/*.json                       ./edition/static/onboard/

# build
ENV CGO_ENABLED=0 GOFLAGS="-trimpath"
# If your repo uses the Go toolchain directive, this ensures auto-download if ever needed:
ENV GOTOOLCHAIN=auto
RUN env GODEBUG=tls13=1 go build -mod=vendor -o bin/documize-community ./edition/community.go

# ---------- Runtime ----------
FROM alpine:3.16
RUN apk add --no-cache ca-certificates
COPY --from=builder /go/src/github.com/documize/community/bin/documize-community /documize
EXPOSE 5001
ENTRYPOINT ["/documize"]
