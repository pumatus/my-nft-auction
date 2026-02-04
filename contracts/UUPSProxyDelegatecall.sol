// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract UUPSProxyDelegatecall {
    // 存储impl 地址
    address public impl;
    address public deployer;

    constructor(address _impl, bytes memory _initData) {
        impl = _impl;
        deployer = msg.sender;

        if (_initData.length > 0) {
            (bool success,) = _impl.delegatecall(_initData);
            require(success, "init failed");
        }
    }

    receive() external payable {
        _delegatecall();
    }

    fallback() external payable {
        _delegatecall();
    }

    function _delegatecall() internal {
        address _impl = impl;
        require(_impl != address(0), "impl need set");
        require(_impl.code.length > 0, "impl has no code");

        (bool success, bytes memory data) = _impl.delegatecall(msg.data);
        // require(success, "Delegatecall failed");
        if (!success) {
            // 还原错误信息
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            } else {
                revert("Delegatecall failed");
            }
        } else {
            // 返回 delegatecall 的返回值. 比如余额
            assembly {
                return(add(data, 32), mload(data))
            }
        }
    }
}
