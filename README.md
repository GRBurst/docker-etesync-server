# ETESync Sever Docker Images

Docker image for [ETESync](https://www.etesync.com/) based on the [server-skeleton](https://github.com/etesync/server-skeleton) repository by [Tom Hacohen](https://github.com/tasn).

## Tags

This build follows some tags of the Python official docker images:

- `edge` [(master:tags/latest/Dockerfile)](https://github.com/grburst/docker-etesync-server/blob/master/tags/latest/Dockerfile)
- `slim`  [(master:tags/slim/Dockerfile)](https://github.com/grburst/docker-etesync-server/blob/master/tags/slim/Dockerfile)
- `alpine` [(master:tags/alpine/Dockerfile)](https://github.com/grburst/docker-etesync-server/blob/master/tags/alpine/Dockerfile)

## Usage

### docker

```bash
docker run -d -e SUPER_USER=admin -e SUPER_USER=admin@example.com -e SUPER_PASS=changeme -p 80:3735 -v /path/on/host:/data grburst/etesync:alpine
```


Create a container running ETESync usiong http protocol.

### docker-compose
You can use docker-compose file, here is an example:

```Dockerfile
version: '3'

services:
  etesync:
    container_name: etesync
    image: grburst/etesync:alpine
    restart: always
    ports:
      - "80:3735"
    volumes:
      - data-etesync:/data
    environment:
      SERVER: ${SERVER:-uwsgi}
      SUPER_USER: ${SUPER_USER:-admin}
      SUPER_EMAIL: ${SUPER_EMAIL:-admin@example.com}
      SUPER_PASS: ${SUPER_PASS:-admin}

volumes:
  data-etesync:
```


### Volumes

`/data`: database file location

### Ports

This image exposes the **3735** TCP Port

### Environment Variables

- **SERVER**: Defines how the container will serve the application, the options are:
  - `http` Runs using HTTP protocol, this is the *default* mode.
  - `https` same as above but with TLS/SSL support, see below how to use with your own certificates.
  - `uwsgi` start using uWSGI native protocol, for reverse-proxies/load balances, such as _nginx_, that support this protocol
  - `http-socket` Similar to the first option, but without uWSGI HTTP router/proxy/load-balancer, this recommended for any reverse-proxies/load balances, that support HTTP protocol, like _traefik_
  - `django-server` this mode uses the embedded django http server, `./manage.py runserver :3735`, this is not recommeded but can be useful for debugging
- **SUPER_USER** and **SUPER_PASS**: Username and password of the django superuser (only used if no previous database is found, both must be used together);
- **SUPER_EMAIL**: Email of the django superuser (optional, only used if no database is found);
- **PUID** and **PGID**: set user and group when running using uwsgi, *default*: `1000`;
- **ETESYNC_DB_PATH**: Location of the ETESync SQLite database. *default*: `/data` volume;
- **DEBUG**: Show debug information in the web interface. *default*: "False"
- **SECRET_KEY**: Provide the value for django's `SECRET_KEY`. When provided, it will be written to `SECRET_FILE` on first startup, otherwise etesync will generate a random key for you.


## Settings and Customization

Custom settings can be added to `/etesync/etesync_site_settings.py`, this file overrides the *default* `settings.py`, mostly for _Django: The Web framework_ options, this image uses the variables below to set some of these options.

### _Environment Variables on `/etesync/etesync_site_settings.py`_

- **ALLOWED_HOSTS**:  the ALLOWED_HOSTS settings, must be valid domains separated by `,`. *default*: `*` (not recommended for production);
- **DEBUG**: enables Django Debug mode, not recommended for production *defaults* to False;
- **LANGUAGE_CODE**: Django language code, *default*: `en-us`;
- **SECRET_FILE**: Defines file that contains the value for django's `SECRET_KEY` if not found a new one is generated. *default*: `/etesync/secret.txt`.
- **USE_TZ**: Force Django to use time-zone-aware datetime objects internally, *defaults* to `false`;
- **TIME_ZONE**: time zone, *defaults* to `UTC`;

### _Using uWSGI with HTTPS_

If you want to run ETESync Server HTTPS using uWSGI you need to pass certificates or the image will generate a self-sign certificate for `localhost`.

By default ETESync will look for the files `/certs/crt.pem` and `/certs/key.pem`, if for some reason you change this location change the **X509_CRT** and **X509_KEY** environment variables

### _Serving Static Files_

When behind a reverse-proxy/http server compatible `uwsgi` protocol the static files are located at `/var/www/etesync/static`, files will be copied if missing on start.

### _Build Variables_
Customize your build. Either when building directly with `docker build`:

```bash
# Build default image
docker build -t [myetesync] -f ./tags/[alpine|latest|slim]/Dockerfile .

# Build with args
docker build --build-arg VAR_NAME=value (...)
```


or adding the following in a `docker-compose` file:

```Dockerfile
services:
  etesync:
    build:
      context: ./build
      args:
        VAR_NAME: value
```

## Examples

### nginx reverse proxy

In many cases, you run it several docker images behind a reverse proxy. Here is how I use it:

Create a `docker network` to let services from different compose files communicate

```bash
docker network create my-reverse-proxy
build: build
```


Nginx `docker-compose` file:

```Dockerfile
version: '3.7'

services:
  nginx:
    container_name: nginx
    build: build
    restart: on-failure
    networks:
      - my-reverse-proxy
      - default
    ports:
      - 80:80
      - 443:443
    volumes:
      - ${TLS_CERTS_DIR:-./.test_certs}:/tls_certs/:ro
      - auth-nginx:/auth/

volumes:
  auth-nginx:

networks:
  reverse-proxy:
    name: my-reverse-proxy
```


... and the etesync `docker-compose` file:

```Dockerfile
version: '3'

services:
  etesync:
    container_name: etesync
    image: grburst/etesync:alpine
    restart: always
    networks:
      - my-reverse-proxy
    expose:
      - "3735"
    volumes:
      - data-etesync:/data
    environment:
      SERVER: ${SERVER:-uwsgi}
      SUPER_USER: ${SUPER_USER:-admin}
      SUPER_EMAIL: ${SUPER_EMAIL:-admin@example.com}
      SUPER_PASS: ${SUPER_PASS:-admin}

volumes:
  data-etesync:

networks:
  my-reverse-proxy:
    external: true
```


In the nginx configuration, you need to an appropriate `*_pass` to your etesync instance, e.g. a `uwsgi_pass`.

Notes:
1. You can use the hostname `etesync` in the `uwsgi_pass` since they are sharing a network
2. In the example, `https_server.include` is a file providing my default https settings for nginx

It will look similar like the following:

```nginx
server {
    server_name etesync.example.com;
    include conf.d/common/https_server.include;
    client_max_body_size       10m;
    client_body_buffer_size    128k;

    location / {
        include     uwsgi_params;
        uwsgi_pass  etesync:3735;
    }
}
```
