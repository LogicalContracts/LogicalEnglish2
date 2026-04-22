# Use the official SWI-Prolog image as the base
FROM swipl:latest

# Set the working directory in the container
WORKDIR /app

# Copy the Prolog source files and examples into the container
COPY *.pl ./
COPY examples/ ./examples/
COPY editor/ ./editor/

# Expose the port the server runs on
EXPOSE 3050

# Command to run the plain web server
# We use -g to start the server and -t halt to ensure it stays in the foreground.
# The server runs in its own threads, so we just need to prevent the main thread from exiting.
CMD ["swipl", "-g", "use_module(classic_web_api), start_api_server(3050)", "-t", "repeat, sleep(1000), fail"]
