FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "sed -i 's/LISTEN_PORT/'\"${PORT:-8080}\"'/g' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
