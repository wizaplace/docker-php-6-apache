# Php 6 + Apache docker image
> PHP6 is dead, long live PHP6!

## Usage
Assuming you are in your sources folder, just run
```
docker run -v $PWD:/var/www/html -p 8080:80 wizaplace/php-6-apache
```
Now, you can play with PHP6 here: `http://localhost:8080/`

## Docker Hub
The image is available on Docker Hub: [wizaplace/php-6-apache](https://hub.docker.com/r/wizaplace/php-6-apache/)
