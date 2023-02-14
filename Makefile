.PHONY: deploy

deploy:
	forge script script/AnvilDeploy.s.sol:AnvilDeployScript --fork-url http://0.0.0.0:8545 --broadcast