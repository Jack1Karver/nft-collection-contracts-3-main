pragma ton-solidity >= 0.43.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import '../../libraries/Common.sol';

interface IMultisig {
    function submitTransaction(
        address dest,
        uint128 value,
        bool bounce,
        bool allBalance,
        TvmCell payload)
    external returns (uint64 transId);

    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload)
    external;
}

struct RootParams{
    address addrOwner;    
    string title;
    uint limit;
    bytes icon;
}

struct TransferParams {
    address addrIndex;
    address addrData;
    address addrTo;
}
