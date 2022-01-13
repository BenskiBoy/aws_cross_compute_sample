# Lambda Sample
A little sample repo for a lambda build using docker.


## Build
### Dev
`make build-dev`

### Prod
`make build-release`

## Test
### Dev
`make unit-test-dev`

### Prod
`make unit-test-release`


## Publish
### Dev
`make publish-dev`

### Prod
`make publish-release`


## Local Test
Start lambda with:
`make start-local-dev`

Invoke with:
`curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d @./tests/sample_event.json`