SWIFT_BUILD_FLAGS=--configuration release

build:
	swift build -v $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

test:
	swift test -v

update:
	swift package update

docker:
	-DOCKER_HOST=tcp://192.168.111.209:2376 docker buildx create --name cluster --platform linux/arm64/v8 --append
	-DOCKER_HOST=tcp://192.168.111.198:2376 docker buildx create --name cluster --platform linux/amd64 --append
	-docker buildx use cluster
	-docker buildx inspect --bootstrap
	-docker login
	#docker buildx build --platform linux/amd64,linux/arm64/v8 .
	docker buildx build --platform linux/amd64 .