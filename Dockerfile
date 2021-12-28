FROM public.ecr.aws/lambda/python:3.9
WORKDIR /opt/app

ADD requirements.txt .
RUN pip install -r requirements.txt

ADD app app

CMD python app/main.py