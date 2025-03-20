# First stage: Build the application
FROM amazoncorretto:17-alpine3.20-jdk AS builder
# Set the working directory inside the container
WORKDIR /app
# Copy the Maven wrapper and pom.xml first to leverage layer caching for dependencies
COPY pom.xml ./
# Create Mock NotificationService directory because Maven needs to see it even building SimpleJira :(
COPY ./NotificationService/ ./NotificationService/
# Copy the Maven wrapper and the .mvn directory
COPY .mvn ./SimpleJira/.mvn
# SimpleJira is the child module
COPY --chmod=0755 ./SimpleJira/mvnw  ./SimpleJira/mvnw
COPY ./SimpleJira/pom.xml ./SimpleJira/pom.xml
# Now copy the application source code
COPY ./SimpleJira/src ./SimpleJira/src
# Download dependencies and package the application
RUN ./SimpleJira/mvnw -pl :SimpleJira -am dependency:go-offline clean package -DskipTests

# Second stage: Extract dependencies
FROM eclipse-temurin:17-jre-noble AS extractor
WORKDIR /app
# Copy the packaged JAR from the builder stage
COPY --from=builder /app/SimpleJira/target/SimpleJira-0.0.1-SNAPSHOT.jar ./simple-jira.jar
# Extract the layers from the JAR to optimize run-time performance
RUN java -Djarmode=layertools -jar simple-jira.jar extract

# Final stage: Build minimal image to run the app
FROM eclipse-temurin:17-jre-noble
WORKDIR /app
# Copy the extracted application layers from the extractor stage
COPY --from=extractor /app/dependencies/ ./
COPY --from=extractor /app/spring-boot-loader/ ./
COPY --from=extractor /app/snapshot-dependencies/ ./
COPY --from=extractor /app/application/ ./
# Expose the port the application will run on
EXPOSE 8080
# Entry point to run the Spring Boot application
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
