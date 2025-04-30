# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
# It's copied from the app subdirectory of your build context
COPY app/requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code from the app subdirectory
COPY app/ .

# Make port 8080 available to the world outside this container
EXPOSE 8080

# Define environment variable for the port.
# GKE and Cloud Run often set this PORT variable.
ENV PORT 8080

# Run main.py when the container launches
# Uses the Python interpreter from the base image
CMD ["python", "main.py"]
