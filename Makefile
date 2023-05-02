.PHONY: artifacts, anvil_deploy, clean-artifacts

clean-artifacts:
	rm -rf artifacts

artifacts: 
	mkdir -p artifacts
	cp ./out/ExchangeFacet.sol/ExchangeFacet.json artifacts/ExchangeFacet.json
	cp ./out/ServiceFacet.sol/ServiceFacet.json artifacts/ServiceFacet.json
	cp ./out/FromStorage.sol/FromStorage.json artifacts/FromStorage.json

anvil_deploy:
	forge script script/Deploy.s.sol:AnvilDeployScript --rpc-url http://127.0.0.1:8545 --broadcast --ffi -vvvv
