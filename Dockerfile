# Build stage
FROM maven:latest AS mavenbuild
COPY src /home/app/src
COPY pom.xml /home/app
RUN mvn -f /home/app/pom.xml clean package
# Package stage
FROM openjdk:17-jdk-alpine
COPY --from=mavenbuild /home/app/target/*.jar /app.jar
EXPOSE 8080
CMD ["java","-jar","/app.jar"]
