# Application web statique (HTML/CSS) servie par Nginx
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY style.css /usr/share/nginx/html/style.css
EXPOSE 80
