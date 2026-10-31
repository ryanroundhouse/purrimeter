FROM golang:1.27.3-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /relay .

FROM alpine:3.23
RUN addgroup -g 10001 relay && adduser -D -u 10001 -G relay relay && mkdir /data && chown relay:relay /data
COPY --from=build /relay /relay
USER relay
ENV LISTEN_ADDR=:8080 SIGNING_KEY_FILE=/data/signing.key
EXPOSE 8080
ENTRYPOINT ["/relay"]
