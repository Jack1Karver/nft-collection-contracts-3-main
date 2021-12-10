pragma ton-solidity >= 0.43.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./debotLibraries/Debot.sol";
import "./debotLibraries/Terminal.sol";
import "./debotLibraries/Menu.sol";
import "./debotLibraries/Msg.sol";
import "./debotLibraries/ConfirmInput.sol";
import "./debotLibraries/AddressInput.sol";
import "./debotLibraries/NumberInput.sol";
import "./debotLibraries/AmountInput.sol";
import "./debotLibraries/Sdk.sol";
import "./debotLibraries/Upgradable.sol";
import "./debotLibraries/UserInfo.sol";
import "./debotLibraries/SigningBoxInput.sol";
import "./debotLibraries/INftDebot.sol";
import '../libraries/Common.sol';

import "../NftRoot.sol";
import "../IndexBasis.sol";
import "../Data.sol";
import "../Index.sol";

contract NftDebot is Debot, Upgradable{

    address _addrNFTRoot;
    address _NftAddr;
    uint256 _totalMinted;

    address _addrMultisig;
    address _addrManager;

    uint32 _keyHandle;

    uint128 _price;

    
    uint count = 0; 
    Rarity rarity;
    RootParams _rootParams;    
    TransferParams _transferParams;
    string _rarityName;

    modifier accept() {
        tvm.accept();
        _;
    }
    //Uploaders =============================================

    function setNftRootAddress(address addrRoot) public accept {
        _addrNFTRoot = addrRoot;
    }

    
    //Overrided DeBot functions========================================
    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Test DeBot";
        version = "0.0.1";
        publisher = "publisher name";
        key = "How to use";
        author = "Author name";
        support = address.makeAddrStd(0, 0x000000000000000000000000000000000000000000000000000000000000);
        hello = "Hello, i am an test DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = '';
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, Menu.ID, AddressInput.ID, SigningBoxInput.ID, ConfirmInput.ID, AmountInput.ID  ];
    }
    
    //=========================================================================================
    function start() public override{
        mainMenu();
    }
    function mainMenu() public{
        if(_addrMultisig == address(0)){
            Terminal.print(0, "You need attach token owner");
            attachMultisig();
        }
        else{
            restart();
        }
    }

    function restart() public{
        if(_keyHandle == 0){
            uint[] none;
            SigningBoxInput.get(tvm.functionId(setKeyHandle), "Enter keys to sign", none);
            return;
        }
        menu();
    }   
    
    //check contract status
    function menu() public{
        MenuItem[] _items;
            _items.push(MenuItem("Mint Nft","",tvm.functionId(deployNft)));
        Menu.select("What we will do?","", _items);        
    }

    
    
    
    // deploy NFT ===================================================================================
    function deployNft() public{        
        MenuItem[] items;
        items.push(MenuItem("Common", "", tvm.functionId(setCommon)));
        items.push(MenuItem("Rare", "", tvm.functionId(setRare)));
        items.push(MenuItem("Epic", "", tvm.functionId(setEpic)));
        Menu.select("Choose rarity type", "", items);   
        this.deployNftStep1();    
    }

    function deployNftStep1() public{        
        setNftAddr();
        this.deployNftStep2();
    }

    function deployNftStep2() public {
        Terminal.print(0, "Check the entered information");
        Terminal.print(0, format("Nft address: {}", _NftAddr));
        Terminal.print(0, format("Rarity type: {}", _rarityName));
        Terminal.print(0, format("Nft Owner: {}", _addrMultisig));
         Menu.select("Continue?","", [
            MenuItem("Yes","", tvm.functionId(deployNftFinally)),
            MenuItem("No", "", tvm.functionId(restart))
        ]);
    }

    function deployNftFinally() public view {
        TvmCell payload = tvm.encodeBody(
            NftRoot.mintNft,
            _rarityName           
        );
        optional(uint256) none;
        IMultisig(_addrMultisig).sendTransaction{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: none,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(onNftDeploySuccess),
            onErrorId: tvm.functionId(onError),
            signBoxHandle: _keyHandle
        }(_addrNFTRoot, 2 ton, true, 3, payload);
    }

    // resolvers ====================================================================================
    function setNftAddr() public accept{
        NftRoot(_addrNFTRoot).getTokenData{
           abiVer: 2,
            extMsg: true,
            callbackId: tvm.functionId(resolveNftDataAddr),
            onErrorId: 0,
            time: 0,
            expire: 0,
            sign: false
        }();
    }   
    
    
    function resolveNftDataAddr(TvmCell code, uint totalMinted) public {
        TvmBuilder salt;
        salt.store(_addrNFTRoot);
        TvmCell codeData = tvm.setCodeSalt(code, salt.toCell());
        TvmCell stateNftData = tvm.buildStateInit({
            contr: Data,
            varInit: {_id: totalMinted},
            code: codeData
        });
        uint256 hashStateNftData = tvm.hash(stateNftData);
        _NftAddr = address.makeAddrStd(0, hashStateNftData);
    }

    
    

    
    // setters=======================================================================================

    function setCommon() public{
        _rarityName = "Common";
    }

    function setRare() public{
        _rarityName = "Rare";
    }

    function setEpic() public{
        _rarityName = "Epic";
    }

    function nftSetParamsRarity(string value) public{
        _rarityName = value;
        this.deployNftStep1();
    }     

    function setKeyHandle(uint32 handle) public {
        _keyHandle = handle;
        restart();
    }

     function attachMultisig() public {
        AddressInput.get(tvm.functionId(saveMultisig), "Attach Multisig\nEnter address:");
    }

    function saveMultisig(address value) public{
        _addrMultisig = value;
        restart();
    }

   
    // helpers====================================================================
    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Sdk error {}. Exit code {}.", sdkError, exitCode));
        restart();
    }

    function tokenInfo() public accept{
        Terminal.print(0, "Your NFT info");
         Data(_NftAddr).getInfo{
            abiVer: 2,
            extMsg: true,
            callbackId: tvm.functionId(checkResult),
            onErrorId: 0,
            time: 0,
            expire: 0,
            sign: false
        }();
    }
    function onNftDeploySuccess() public{
        MenuItem[] items;
        items.push(MenuItem("Check NFT data", "",tvm.functionId(tokenInfo)));
        items.push(MenuItem("Restart", "", tvm.functionId(restart)));
        Menu.select("What we will do?", "", items);
    }
    function checkResult(
        address addrData,
        address addrRoot,
        address addrOwner,
        address addrTrusted,
        string rarityType
    ) public {
        Terminal.print(0, 'Data of deployed token: ');
        Terminal.print(0, format("Token address: {}", addrData));
        Terminal.print(0, format("Root: {}", addrRoot));
        Terminal.print(0, format("Owner: {}", addrOwner));
        Terminal.print(0, format("Address trusted {}\n", addrTrusted));
        Terminal.print(0, format("Rarity Type: {}\n", rarityType)); 
        onNftDeploySuccess();
    }
    

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }

}

