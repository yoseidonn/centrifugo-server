FROM centrifugo/centrifugo:v5

# Copy configuration
COPY config.json /centrifugo/config.json

# Create logs directory
RUN mkdir -p /var/log/centrifugo

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run Centrifugo
CMD ["centrifugo", "--config=/centrifugo/config.json"]
