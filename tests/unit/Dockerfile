ARG base_image
FROM $base_image

RUN pip install pytest
RUN pip install pytest-cov

ARG aws_region
ENV AWS_DEFAULT_REGION $aws_region

ADD *.py .

# Override lambda base image entrypoint
ENTRYPOINT ["/bin/bash", "-l", "-c"]