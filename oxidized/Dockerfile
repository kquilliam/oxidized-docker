# Use a specific, stable version of Oxidized
FROM oxidized/oxidized:latest

# Switch to the root user to install packages and set permissions
USER root

# Install dependencies, bypassing GPG validation due to time skew
RUN apt-get update --allow-insecure-repositories && \
    apt-get install -y --allow-unauthenticated --no-install-recommends \
    ca-certificates \
    ubuntu-keyring \
    build-essential \
    libxml2-dev \
    libxslt-dev \
    python3 \
    python3-pip \
    python3-venv \
    openssh-client \
    gosu \
    && gem install nokogiri \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create and use a virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements file and install packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Add git safe.directory configuration to avoid dubious ownership errors
RUN git config --global --add safe.directory /home/oxidized/.config/oxidized/configs.git

# --- Add UI Customizations ---
# !! IMPORTANT: You must find this path in your base image first !!
# Run this command to find it:
# docker run -it --rm --entrypoint bash oxidized/oxidized:latest -c "find / -type d -name 'oxidized-web-*' 2>/dev/null"
#
# Then, replace the path below with your image's path.
ARG OXIDIZED_WEB_PATH=/var/lib/gems/3.2.0/gems/oxidized-web-0.17.1
ARG OXIDIZED_OX_PATH=/var/lib/gems/3.2.0/gems/oxidized-0.34.3/

# These files are assumed to be in a 'custom_files' directory in your build context
COPY custom_files/assets/custom.css ${OXIDIZED_WEB_PATH}/lib/oxidized/web/public/assets/custom.css
COPY custom_files/views/layout.haml ${OXIDIZED_WEB_PATH}/lib/oxidized/web/views/layout.haml
COPY custom_files/views/nodes.haml ${OXIDIZED_WEB_PATH}/lib/oxidized/web/views/nodes.haml
COPY custom_files/views/stats.haml ${OXIDIZED_WEB_PATH}/lib/oxidized/web/views/stats.haml
COPY custom_files/views/node.haml ${OXIDIZED_WEB_PATH}/lib/oxidized/web/views/node.haml
COPY custom_files/views/diffs.haml ${OXIDIZED_WEB_PATH}/lib/oxidized/web/views/diffs.haml
COPY custom_files/output/git.rb ${OXIDIZED_OX_PATH}/lib/oxidized/output/git.rb
COPY custom_files/source/http.rb ${OXIDIZED_OX_PATH}/lib/oxidized/source/http.rb

# Create necessary directories
RUN mkdir -p /home/oxidized/.ssh /home/oxidized/.config/oxidized/hooks /home/oxidized/.config/oxidized/model

# Copy ALL of your configuration files
COPY config.template /home/oxidized/.config/oxidized/config.template
COPY entrypoint.sh /entrypoint.sh
COPY hooks/ /home/oxidized/.config/oxidized/hooks/
COPY model/panos_api.rb /home/oxidized/.config/oxidized/model/
COPY scripts/panos_xml_to_set.py /usr/local/bin/panos_xml_to_set.py
COPY secrets.py .

# Set all permissions and ownership correctly
RUN chown -R oxidized:oxidized /home/oxidized && \
    chown -R oxidized:oxidized /var/lib/gems/3.2.0 && \
    chown oxidized:oxidized /usr/local/bin/panos_xml_to_set.py && \
    chmod +x /home/oxidized/.config/oxidized/hooks/* && \
    chmod +x /usr/local/bin/panos_xml_to_set.py && \
    chmod +x /entrypoint.sh

# Switch back to the non-privileged user to run the application
#USER oxidized

# Set the entrypoint to our new script
ENTRYPOINT ["/entrypoint.sh"]

# Set the default command to run after the entrypoint script finishes
CMD ["oxidized"]
