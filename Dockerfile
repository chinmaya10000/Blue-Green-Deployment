# FROM eclipse-temurin:24-jdk-alpine
    
# EXPOSE 8080
 
# ENV APP_HOME /usr/src/app

# COPY target/*.jar $APP_HOME/app.jar

# WORKDIR $APP_HOME

# CMD ["java", "-jar", "app.jar"]

# ---- Stage 1: Build Stage ----
FROM maven:3.9.9-eclipse-temurin-24-alpine AS build

WORKDIR /app
    
# Copy only necessary files to leverage caching
COPY pom.xml .
RUN mvn dependency:go-offline
    
# Copy rest of the project
COPY src ./src
    
# Build the application
RUN mvn clean package -DskipTests
    
# ---- Stage 2: Runtime Stage ----
FROM eclipse-temurin:24-jdk-alpine
    
# App will run on port 8080
EXPOSE 8080
    
# Set environment variable
ENV APP_HOME /usr/src/app
    
# Create app directory
WORKDIR $APP_HOME
    
# Copy the built JAR from the build stage
COPY --from=build /app/target/*.jar $APP_HOME/app.jar
    
# Run the app
CMD ["java", "-jar", "app.jar"]
    