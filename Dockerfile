# Build the image:
#   docker build -t le2 .
#
# Run locally:
#   docker run -p 3050:3050 le2
#
# Push to Docker Hub:
#   docker tag le2 logicalcontracts/le2:latest
#   docker push logicalcontracts/le2:latest
#
# Pull and run as a server:
#   docker pull logicalcontracts/le2:latest
#   docker run -d -p 8084:3050 --name le2_server logicalcontracts/le2:latest
#

# Use the official SWI-Prolog image as the base
FROM swipl:latest

# Install Node.js, git, and opencode
RUN apt-get update && apt-get install -y curl git gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g opencode-ai mcp-remote && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the Prolog source files and examples into the container
COPY *.pl ./
COPY *.db ./
COPY examples/ ./examples/
COPY llm/ ./llm/
COPY editor/ ./editor/
COPY web_extras/ ./web_extras/
COPY docs/ ./docs/
COPY AGENTS_LE_template.md ./
COPY opencode.json ./

# Set environment variables for opencode
ENV OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true

# Build the editor
RUN cd editor && npm install --legacy-peer-deps && npm run build

ARG BUILD_INFO="unknown"
RUN echo "${BUILD_INFO}" > build_info.txt

# Expose the port the server runs on
EXPOSE 3050

# Command to run the plain web server
# We use -g to start the server and -t halt to ensure it stays in the foreground.
# The server runs in its own threads, so we just need to prevent the main thread from exiting.
CMD ["swipl", "-g", "use_module(classic_web_api), start_api_server(3050)", "-t", "repeat, sleep(1000), fail"]
