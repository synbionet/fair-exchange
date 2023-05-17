.PHONY: artifacts, anvil_deploy, clean-artifacts, test

clean-artifacts:
	rm -rf artifacts

artifacts: 
	mkdir -p artifacts
	cp ./out/ExchangeFacet.sol/ExchangeFacet.json artifacts/ExchangeFacet.json
	cp ./out/ServiceFacet.sol/ServiceFacet.json artifacts/ServiceFacet.json
	cp ./out/FromStorage.sol/FromStorage.json artifacts/FromStorage.json
	cp ./out/USDC.sol/USDC.json artifacts/USDC.json

anvil_deploy:
	forge script script/Deploy.s.sol:AnvilDeployScript --rpc-url http://127.0.0.1:8545 --broadcast --ffi -vvvv

test:
	forge test --ffi -vv
