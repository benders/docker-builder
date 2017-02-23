```
docker build -t base-alpine-builder base-alpine-builder

docker build -t example-app example-app

docker run -p8000:80 -eRAILS_ENV=development example-app
```
