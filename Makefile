.PHONY: artifacts, anvil_deploy, clean-artifacts, test

clean-artifacts:
	rm -rf artifacts

artifacts: 
	mkdir -p artifacts
	cp ./out/ExchangeFacet.sol/ExchangeFacet.json artifacts/ExchangeFacet.json
	cp ./out/ServiceFacet.sol/ServiceFacet.json artifacts/ServiceFacet.json
	cp ./out/FromStorage.sol/FromStorage.json artifacts/FromStorage.json
	cp ./out/Treasury.sol/Treasury.json artifacts/Treasury.json
	cp ./out/USDC.sol/USDC.json artifacts/USDC.json

local_deploy:
	forge script script/LocalDeploy.s.sol:LocalDeployScript --rpc-url http://127.0.0.1:8545 --broadcast --ffi -vvvv

test:
	forge test --ffi -vv

run_sim: 
	forge script script/Sim.s.sol:SimScript --rpc-url http://127.0.0.1:8545 --broadcast --ffi -vvvv

