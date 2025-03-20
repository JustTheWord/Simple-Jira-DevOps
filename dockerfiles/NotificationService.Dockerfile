# First stage: Build the application
FROM amazoncorretto:17-alpine3.20-jdk AS builder
WORKDIR /app
# Copy the Maven wrapper and pom.xml first to leverage layer caching for dependencies
COPY pom.xml ./
COPY .mvn ./NotificationService/.mvn
COPY --chmod=0755 ./NotificationService/mvnw ./NotificationService/mvnw
# Copy the parent POM and module structure for dependency resolution
COPY ./SimpleJira/ ./SimpleJira/
COPY ./NotificationService/pom.xml ./NotificationService/pom.xml
# Now copy the application source code
COPY ./NotificationService/src ./NotificationService/src
# Download dependencies and package the application
RUN ./NotificationService/mvnw -pl :NotificationService -am dependency:go-offline clean package -DskipTests

# Second stage: Extract dependencies
FROM eclipse-temurin:17-jre-noble AS extractor
WORKDIR /app
# Copy the packaged JAR from the builder stage
COPY --from=builder /app/NotificationService/target/NotificationService-0.0.1-SNAPSHOT.jar ./notification-service.jar
# Extract the layers from the JAR to optimize run-time performance
RUN java -Djarmode=layertools -jar notification-service.jar extract

# Final stage: Build minimal image to run the app
FROM eclipse-temurin:17-jre-noble
WORKDIR /app
# Copy the extracted application layers from the extractor stage
COPY --from=extractor /app/dependencies/ ./
COPY --from=extractor /app/spring-boot-loader/ ./
COPY --from=extractor /app/snapshot-dependencies/ ./
COPY --from=extractor /app/application/ ./
# Expose the port the application will run on
EXPOSE 8081
# Entry point to run the Spring Boot application
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
