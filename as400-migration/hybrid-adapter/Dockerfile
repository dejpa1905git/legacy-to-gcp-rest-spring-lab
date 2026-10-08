# ==============================================================================
# Build Stage: Compile and package using Eclipse Temurin JDK 21 Alpine & Maven
# ==============================================================================
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /workspace

# Install dos2unix or sed tools for cross-platform wrapper compatibility
RUN apk add --no-cache bash

# Copy Maven wrapper configuration and dependencies descriptor
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN sed -i 's/\r$//' mvnw && chmod +x mvnw

# Resolve project dependencies offline for layer caching
RUN ./mvnw dependency:go-offline -B

# Copy application source code
COPY src ./src

# Build production JAR (skipping remote tests during container packaging)
RUN ./mvnw clean package -DskipTests

# ==============================================================================
# Run Stage: Production-grade minimal JRE runtime
# ==============================================================================
FROM eclipse-temurin:21-jre-alpine AS runner
WORKDIR /app

# Cloud Run dynamic port injection (defaults to 8080)
ENV PORT=8080
EXPOSE 8080

# Security hardening: Run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy compiled executable JAR from builder stage
COPY --from=builder /workspace/target/*.jar app.jar

# Run Spring Boot respecting the injected PORT environment variable
ENTRYPOINT ["sh", "-c", "java -Dserver.port=${PORT} -jar app.jar"]

