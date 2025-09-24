# Usar imagen base Eclipse Temurin (más rápida y sin problemas de timezone)
FROM eclipse-temurin:21-jre-alpine

# Información del mantenedor
LABEL maintainer="jlzDev"
LABEL description="Sistema de inventario para tienda"
LABEL version="1.0.0"

# Establecer variables de entorno
ENV TZ=America/Bogota
ENV SPRING_PROFILES_ACTIVE=docker

# Configurar zona horaria directamente (Alpine Linux)
RUN apk add --no-cache \
    curl \
    tzdata \
    && cp /usr/share/zoneinfo/America/Bogota /etc/localtime \
    && echo "America/Bogota" > /etc/timezone

# Crear usuario para la aplicación (Alpine Linux)
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Crear directorio de la aplicación
RUN mkdir -p /opt/inventario && \
    mkdir -p /var/log/inventario && \
    chown -R appuser:appgroup /opt/inventario && \
    chown -R appuser:appgroup /var/log/inventario

# Copiar el JAR de la aplicación
COPY app/inventario-tienda-0.0.1-SNAPSHOT.jar /opt/inventario/app.jar
COPY app/application-docker.properties /opt/inventario/application-docker.properties

# Cambiar permisos
RUN chown appuser:appgroup /opt/inventario/app.jar

# Cambiar al usuario de la aplicación
USER appuser

# Establecer directorio de trabajo
WORKDIR /opt/inventario

# Exponer puerto
EXPOSE 8080

# Verificar que Java está instalado
RUN java -version

# Configurar punto de entrada de la aplicación
ENTRYPOINT ["java", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dspring.profiles.active=docker", \
    "-Duser.timezone=America/Bogota", \
    "-Xmx512m", \
    "-Xms256m", \
    "-jar", \
    "app.jar"]