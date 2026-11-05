FROM nginx:1.27-alpine

ARG BUILD_NUMBER=local

# Copy only the site files into nginx's web root
COPY index.html  /usr/share/nginx/html/

# Write the build number so we can verify which version is live
RUN echo "${BUILD_NUMBER}" > /usr/share/nginx/html/version.txt

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/ >/dev/null || exit 1
