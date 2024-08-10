// SPDX-License-Identifier: MIT

/**
Website: https://trump407.xyz
X: https://x.com/trump407
Telegram: https://t.me/Trump_407
Powered by: https://memehub.ai
*/

pragma solidity ^0.8.0;

pragma solidity ^0.8.0;

interface IERC20 {
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.8.0;

abstract contract Ownable {
    event OwnershipTransferred(address indexed user, address indexed newOwner);

    error Unauthorized();
    error InvalidOwner();

    address public owner;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    constructor(address _owner) {
        if (_owner == address(0)) revert InvalidOwner();

        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    function transferOwnership(address _owner) public virtual onlyOwner {
        if (_owner == address(0)) revert InvalidOwner();

        owner = _owner;

        emit OwnershipTransferred(msg.sender, _owner);
    }

    function revokeOwnership() public virtual onlyOwner {
        owner = address(0);

        emit OwnershipTransferred(msg.sender, address(0));
    }
}

abstract contract ERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721Receiver.onERC721Received.selector;
    }
}

/// @notice ERC404
///         A gas-efficient, mixed ERC20 / ERC721 implementation
///         with native liquidity and fractionalization.
///
///         This is an experimental standard designed to integrate
///         with pre-existing ERC20 / ERC721 support as smoothly as
///         possible.
///
/// @dev    In order to support full functionality of ERC20 and ERC721
///         supply assumptions are made that slightly constraint usage.
///         Ensure decimals are sufficiently large (standard 18 recommended)
///         as ids are effectively encoded in the lowest range of amounts.
///
///         NFTs are spent on ERC20 functions in a FILO queue, this is by
///         design.
///
abstract contract ERC404 is Ownable {
    // Events
    event ERC20Transfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event ERC721Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Errors
    error NotFound();
    error AlreadyExists();
    error InvalidRecipient();
    error InvalidSender();
    error UnsafeRecipient();

    // Metadata
    /// @dev Token name
    string public name;

    /// @dev Token symbol
    string public symbol;

    /// @dev Decimals for fractional representation
    uint8 public immutable decimals;

    /// @dev Total supply in fractionalized representation
    uint256 public immutable totalSupply;

    /// @dev Current mint counter, monotonically increasing to ensure accurate ownership
    uint256 public minted;

    // Mappings
    /// @dev Balance of user in fractional representation
    mapping(address => uint256) public balanceOf;

    /// @dev Allowance of user in fractional representation
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev Approval in native representaion
    mapping(uint256 => address) public getApproved;

    /// @dev Approval for all in native representation
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @dev Owner of id in native representation
    mapping(uint256 => address) internal _ownerOf;

    /// @dev Array of owned ids in native representation
    mapping(address => uint256[]) internal _owned;

    /// @dev Tracks indices for the _owned mapping
    mapping(uint256 => uint256) internal _ownedIndex;

    /// @dev Addresses whitelisted from minting / burning for gas savings (pairs, routers, etc)
    mapping(address => bool) public whitelist;

    // Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalNativeSupply,
        address _owner
    ) Ownable(_owner) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalNativeSupply * (10 ** decimals);
    }

    /// @notice Initialization function to set pairs / etc
    ///         saving gas by avoiding mint / burn on unnecessary targets
    function setWhitelist(address target, bool state) public onlyOwner {
        whitelist[target] = state;
    }

    /// @notice Function to find owner of a given native token
    function ownerOf(uint256 id) public view virtual returns (address owner) {
        owner = _ownerOf[id];

        if (owner == address(0)) {
            revert NotFound();
        }
    }

    /// @notice tokenURI must be implemented by child contract
    function tokenURI(uint256 id) public view virtual returns (string memory);

    /// @notice Function for token approvals
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function approve(
        address spender,
        uint256 amountOrId
    ) public virtual returns (bool) {
        if (amountOrId <= minted && amountOrId > 0) {
            address owner = _ownerOf[amountOrId];

            if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
                revert Unauthorized();
            }

            getApproved[amountOrId] = spender;

            emit Approval(owner, spender, amountOrId);
        } else {
            allowance[msg.sender][spender] = amountOrId;

            emit Approval(msg.sender, spender, amountOrId);
        }

        return true;
    }

    /// @notice Function native approvals
    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Function for mixed transfers
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function transferFrom(
        address from,
        address to,
        uint256 amountOrId
    ) public virtual {
        if (amountOrId <= minted) {
            if (from != _ownerOf[amountOrId]) {
                revert InvalidSender();
            }

            if (to == address(0)) {
                revert InvalidRecipient();
            }

            if (
                msg.sender != from &&
                !isApprovedForAll[from][msg.sender] &&
                msg.sender != getApproved[amountOrId]
            ) {
                revert Unauthorized();
            }

            balanceOf[from] -= _getUnit();

            unchecked {
                balanceOf[to] += _getUnit();
            }

            _ownerOf[amountOrId] = to;
            delete getApproved[amountOrId];

            // update _owned for sender
            uint256 updatedId = _owned[from][_owned[from].length - 1];
            _owned[from][_ownedIndex[amountOrId]] = updatedId;
            // pop
            _owned[from].pop();
            // update index for the moved id
            _ownedIndex[updatedId] = _ownedIndex[amountOrId];
            // push token to to owned
            _owned[to].push(amountOrId);
            // update index for to owned
            _ownedIndex[amountOrId] = _owned[to].length - 1;

            emit Transfer(from, to, amountOrId);
            emit ERC20Transfer(from, to, _getUnit());
        } else {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max)
                allowance[from][msg.sender] = allowed - amountOrId;

            _transfer(from, to, amountOrId);
        }
    }

    /// @notice Function for fractional transfers
    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    /// @notice Function for native transfers with contract support
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Function for native transfers with contract support and callback data
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Internal function for fractional transfers
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual returns (bool) {
        uint256 unit = _getUnit();
        uint256 balanceBeforeSender = balanceOf[from];
        uint256 balanceBeforeReceiver = balanceOf[to];

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        // Skip burn for certain addresses to save gas
        if (!whitelist[from]) {
            uint256 tokens_to_burn = (balanceBeforeSender / unit) -
                (balanceOf[from] / unit);
            for (uint256 i = 0; i < tokens_to_burn; i++) {
                _burn(from);
            }
        }

        // Skip minting for certain addresses to save gas
        if (!whitelist[to]) {
            uint256 tokens_to_mint = (balanceOf[to] / unit) -
                (balanceBeforeReceiver / unit);
            for (uint256 i = 0; i < tokens_to_mint; i++) {
                _mint(to);
            }
        }

        emit ERC20Transfer(from, to, amount);
        return true;
    }

    // Internal utility logic
    function _getUnit() internal view returns (uint256) {
        return 10 ** decimals;
    }

    function _mint(address to) internal virtual {
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        unchecked {
            minted++;
        }

        uint256 id = minted;

        if (_ownerOf[id] != address(0)) {
            revert AlreadyExists();
        }

        _ownerOf[id] = to;
        _owned[to].push(id);
        _ownedIndex[id] = _owned[to].length - 1;

        emit Transfer(address(0), to, id);
    }

    function _burn(address from) internal virtual {
        if (from == address(0)) {
            revert InvalidSender();
        }

        uint256 id = _owned[from][_owned[from].length - 1];
        _owned[from].pop();
        delete _ownedIndex[id];
        delete _ownerOf[id];
        delete getApproved[id];

        emit Transfer(from, address(0), id);
    }

    // function _setNameSymbol(
    //     string memory _name,
    //     string memory _symbol
    // ) internal {
    //     name = _name;
    //     symbol = _symbol;
    // }
}

pragma solidity ^0.8.0;

library EnumerableSet {
    struct Set {
        bytes32[] _values;
        mapping (bytes32 => uint256) _indexes;
    }

    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    function _remove(Set storage set, bytes32 value) private returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            bytes32 lastvalue = set._values[lastIndex];

            set._values[toDeleteIndex] = lastvalue;
            set._indexes[lastvalue] = toDeleteIndex + 1;
            set._values.pop();
            delete set._indexes[value];
            return true;
        } else {
            return false;
        }
    }
    
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    struct AddressSet {
        Set _inner;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
   
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }
}

pragma solidity ^0.8.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

pragma solidity ^0.8.0;

abstract contract ReentrancyGuard {
    uint256 private locked = 1;

    modifier nonReentrant() virtual {
        require(locked == 1, "REENTRANCY");

        locked = 2;

        _;

        locked = 1;
    }
}

interface IDEXPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function totalSupply() external view returns (uint256);
}

interface IDEXFactory {
    function createPair(
        address tokenA, 
        address tokenB
    ) external returns (address pair);
    function getPair(
        address tokenA, 
        address tokenB
    ) external view returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

library ERC20Events {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );
}

library ERC721Events {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
}

contract ERC407 is ERC404, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    error AddressTooLow();
    error InvalidID();
    error InvalidLength();
    error NotStarted();
    error AlreadyStarted();
    error OutOfRange();
    error AmountTooLow();
    error EmptyArray();
    error NoRewards();
    error BlackList();

    struct BurnData {
        uint256 amount;
        uint256 value;
        uint256 rewards;
        uint256 rewardsClaimed;
        uint256 lastRewardTime;
    }

    EnumerableSet.AddressSet dividendProviders;

    mapping(uint256 => uint256) private _mintTime;
    mapping(address => bool) public isPairs;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _blackList;
    mapping(address => BurnData) public burnData;

    string public dataURI = "https://cdn.trump407.xyz/nft/";
    string public baseTokenURI;

    uint256 private constant MAX = ~uint256(0);
    uint256 public constant amountPerNFT = 10000 * 1e18;
    uint256 _initialSupply = 8e8;

    IDEXRouter public dexRouter;
    address public dexPair;
    address public wbnbUsdtPair;
    address public constant deadAddress = address(0xdead);

    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;

    address public constant trumpAddress = 0x94845333028B1204Fbe14E1278Fd4Adde46B22ce;
    address public constant politicianAddress = 0xeF0D482Daa16fa86776Bc582Aff3dFce8d9b8396;
    address public marketAddress = 0xc29043506b5690Dd08587A0CE9D218204A532bEd;
    address private _owner = 0x63475E00297f5e17b09a2B0a2ca03E88b83d3854;
    address public rewardPool = 0x2E2Ddbb9Ad9A2E8B0937A0a469DBAC1b1C45393f;

    uint256 public poolRate = 3000;
    uint256 public trumpRate = 5000;
    uint256 public rewardMultiple = 3;
    uint256 public burnCondition = 50000 * 1e18;
    uint256 private currentIndex;
    uint256 private constant distributorGas = 500000;

    uint256 public totalAccumulatedUsdt;
    uint256 public totalRewards;
    uint256 public totalBurnAmount;
    uint256 public marketAmount;

    uint256 public buyBackFee = 50;
    uint256 public rewardFee = 150;
    uint256 public burnFee = 100;
    uint256 public totalFee = 300;
    uint256 private constant feeUnit = 10000;

    uint256 public swapThreshold;
    bool public swapEnabled = true;
    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    constructor(
    ) ERC404("Trump407", "Trump407", 18, _initialSupply, _owner) {
        if (address(this) <= wbnb) revert AddressTooLow();
        swapThreshold = _initialSupply / 2000;
        balanceOf[_owner] = _initialSupply * 1e18;

        whitelist[_owner] = true;
        whitelist[address(this)] = true;
        whitelist[marketAddress] = true;
        whitelist[rewardPool] = true;
        whitelist[deadAddress] = true;

        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[deadAddress] = true;
        _isExcludedFromFee[trumpAddress] = true;
        _isExcludedFromFee[politicianAddress] = true;
        _isExcludedFromFee[marketAddress] = true;
        _isExcludedFromFee[rewardPool] = true;

        dexRouter = IDEXRouter(router);
        IERC20(wbnb).approve(address(dexRouter), MAX);
        isApprovedForAll[address(this)][router] = true;

        IDEXFactory dexFactory = IDEXFactory(dexRouter.factory());
        dexPair = dexFactory.createPair(address(this), wbnb);
        isPairs[dexPair] = true;

        wbnbUsdtPair = dexFactory.getPair(wbnb, usdt);
    }

    receive() external payable {}

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function setSwapBackSettings(
        bool _enabled, 
        uint256 _amount
    ) external onlyOwner {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function setWhitelistByPool(address account, bool _status) external {
        if (msg.sender != rewardPool && msg.sender != owner) revert Unauthorized();

        whitelist[account] = _status;
    }

    function multiSetWhiteList(
        address[] calldata accounts, 
        bool _status
    ) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = _status;
        }
    }

    function multiSetExcludeFromFee(
        address[] calldata accounts, 
        bool _status
    ) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = _status;
        }
    }

    function multiSetBlackList(
        address[] calldata accounts, 
        bool _status
    ) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            _blackList[accounts[i]] = _status;
        }
    }

    function setRewardMultiple(uint256 _multiple) external onlyOwner {
        rewardMultiple = _multiple;
    }

    function setRate(uint256 _rate0, uint256 _rate1) external onlyOwner {
        if (_rate0 > feeUnit || _rate1 > feeUnit) revert OutOfRange();
        poolRate = _rate0;
        trumpRate = _rate1;
    }

    function setCondition(
        uint256 _bc
    ) external onlyOwner {
        burnCondition = _bc;
    }

    function changeRewardPool(address _pool) external {
        if (msg.sender != rewardPool && msg.sender != owner) revert Unauthorized();

        rewardPool = _pool;
        _isExcludedFromFee[_pool] = true;
        whitelist[_pool] = true;
    }

    function idsOwnerCheck(uint256[] memory ids, address account) public view returns (bool result) {
        result = true;
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 id = ids[i];
            if (_ownerOf[id] != account) {
                result = false;
                break;
            }
        }
    }

    function getBalanceOf(address account) public view returns (uint256, uint256) {
        return (balanceOf[account], IERC20(usdt).balanceOf(account));
    }

    struct ImageInfo {
        uint256 id;
        uint256 number;
        string category;
        string name;
    }
    function getImageInfo(uint256 id) public view returns (ImageInfo memory imageInfo){
        if (id > minted) revert InvalidID();

        (, uint256 number, string memory category, string memory name) = _getImage(id);
        imageInfo.id = id;
        imageInfo.number = number;
        imageInfo.category = category;
        imageInfo.name = name;
        return imageInfo;
    }

    function getImageInfos(uint256[] memory ids) public view returns (ImageInfo[] memory imageInfos) {
        uint256 length = ids.length;
        imageInfos = new ImageInfo[](length);
        for (uint256 i = 0; i < length; i++) {
            imageInfos[i] = getImageInfo(ids[i]);
        }
        return imageInfos;
    }

    function getUserImageInfos(address account) public view returns (ImageInfo[] memory imageInfos) {
        uint256[] memory ids = _owned[account];
        return getImageInfos(ids);
    }

    function _getImage(uint256 id) internal view returns (string memory, uint256, string memory, string memory) {
        uint256 number = 1;
        string memory category;
        string memory name;

        uint24 seed = uint24(bytes3(keccak256(abi.encodePacked(id + _mintTime[id]))));
        uint24[31] memory interval = [2872277, 5482411, 5484842, 7832832, 7833344, 9919190, 9919318, 11743020, 11743021, 11744045, 11952432, 11952944, 12169523, 12170035, 12402998, 12627769, 12975420, 13314879, 13646146, 13969221, 14284104, 14590795, 14889294, 15179601, 15461716, 15489520, 15763443, 16029174, 16286713, 16536060, 16777215];
        for (uint256 i = 0; i < interval.length; i++) {
            if (seed <= interval[i]) {
                number = i + 1;
                break;
            }
        }

        string[31] memory nameList = ["Trump-1","Trump-2","Trump-3","Trump-4","Trump-5","Trump-6","Trump-7","Trump-8","Trump-9","Trump-10","Barron","Eric","Ivanka","John","Melania","Tiffany","Biden-1","Biden-2","Biden-3","Harris-1","Harris-2","Kim-1","Kim-2","Kim-3","Kim-4","Kim-5","Kim-6","Obama-1","Putin-1","Putin-2","Putin-3"];
        name = nameList[number - 1];

        if (number <= 10) {
            category = "Trump";
        } else if (number <= 16) {
            category = "Trump-Family";
        } else {
            category = "Other";
        }

        string memory image = string.concat(string.concat('trump407-', toString(number)), '.png');

        return (image, number, category, name);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string.concat(baseTokenURI, toString(id));
        } else {
            string memory image;
            uint256 number;
            string memory category;
            string memory name;
            (image, number, category, name) = _getImage(id);

            string memory jsonPreImage = string.concat(
                string.concat('{"name": "Trump407 ', name),
                string.concat(' #', toString(id))
            );
            string memory jsonPreImage1 = string.concat(
                string.concat(
                    jsonPreImage,
                    '","description":"The world\'s first deflationary NFT, let\'s make America great again together, Trump407 is the largest cryptocurrency supporting Trump\'s camp outside the United States.","external_url":"https://www.trump407.xyz","image":"'
                ),
                string.concat(dataURI, image)
            );

            string memory jsonPostImage = string.concat(
                '","attributes":[{"trait_type":"Number","value":"',
                toString(number)
            );
            string memory jsonPostImage1 = string.concat(
                '"},{"trait_type":"Category","value":"',
                category
            );
            
            string memory j1 = string.concat(jsonPostImage, jsonPostImage1);

            string memory jsonPostTraits = '"}]}';

            return
                string.concat(
                    "data:application/json;utf8,",
                    string.concat(
                        string.concat(jsonPreImage1, j1),
                        jsonPostTraits
                    )
                );
        }
    }

    function _mint(address to) internal override {
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        unchecked {
            minted++;
        }

        uint256 id = minted;

        if (_ownerOf[id] != address(0)) {
            revert AlreadyExists();
        }

        _mintTime[id] = block.timestamp;
        _ownerOf[id] = to;
        _owned[to].push(id);
        _ownedIndex[id] = _owned[to].length - 1;

        emit ERC721Events.Transfer(address(0), to, id);
    }

    function _burn(address from) internal override {
        if (from == address(0)) {
            revert InvalidSender();
        }

        if (_owned[from].length <= 0) {
            return;
        }
        uint256 id = _owned[from][_owned[from].length - 1];
        _owned[from].pop();
        delete _ownedIndex[id];
        delete _ownerOf[id];
        delete getApproved[id];

        emit ERC721Events.Transfer(from, address(0), id);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amountOrId
    ) public override {
        if (amountOrId <= minted) {
            if (from != _ownerOf[amountOrId]) {
                revert InvalidSender();
            }

            if (to == address(0)) {
                revert InvalidRecipient();
            }

            if (
                msg.sender != from &&
                !isApprovedForAll[from][msg.sender] &&
                msg.sender != getApproved[amountOrId]
            ) {
                revert Unauthorized();
            }

            balanceOf[from] = balanceOf[from].sub(amountPerNFT);

            unchecked {
                balanceOf[to] = balanceOf[to].add(amountPerNFT);
            }

            _ownerOf[amountOrId] = to;
            delete getApproved[amountOrId];

            uint256 updatedId = _owned[from][_owned[from].length - 1];
            _owned[from][_ownedIndex[amountOrId]] = updatedId;
            _owned[from].pop();
            _ownedIndex[updatedId] = _ownedIndex[amountOrId];
            _owned[to].push(amountOrId);
            _ownedIndex[amountOrId] = _owned[to].length - 1;

            emit ERC721Events.Transfer(from, to, amountOrId);
            emit ERC20Events.Transfer(from, to, amountPerNFT);
        } else {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max)
                allowance[from][msg.sender] = allowed - amountOrId;

            _transfer(from, to, amountOrId);
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override returns (bool) {
        if (amount <= 0) revert AmountTooLow();

        if(inSwap == true || _isExcludedFromFee[from] == true || _isExcludedFromFee[to] == true){
            return _basicTransfer(from, to, amount);
        }

        if (startTime == 0) revert NotStarted();

        if (_blackList[from] == true) revert BlackList(); 

        bool isSell;
        bool isRemove;
        if (isPairs[from]) {
            isRemove = _checkRemove();
        } else if (isPairs[to]) {
            isSell = true;
        }

        if (!_isExcludedFromFee[from] && isPairs[to] && !inSwap) {
            uint256 fromBalance = balanceOf[from].mul(9999).div(10000);
            if (fromBalance < amount) {
                amount = fromBalance;
            }
        }

        if(shouldSwapBack(to)){ swapBack(); }

        if (
            from != address(this) 
            && IERC20(usdt).balanceOf(address(this)) > 0 
            && totalBurnAmount > 0 ) {
            process(distributorGas);
        }

        if (isRemove) {
            return _basicTransfer(from, deadAddress, amount);
        }

        uint256 feeAmount;
        if (block.timestamp - startTime < highFeeDuration && isSell){
            feeAmount = amount.mul(highSellFee).div(feeUnit);
            marketAmount = marketAmount.add(feeAmount);
        } else if (block.timestamp - startTime < highFeeDuration && !isPairs[from]){
            feeAmount = amount.mul(highTransferFee).div(feeUnit);
            marketAmount = marketAmount.add(feeAmount);
        } else {
            feeAmount = amount.mul(totalFee).div(feeUnit);
        }
        if (feeAmount > 0) {
            _basicTransfer(from, address(this), feeAmount);
        }

        return _basicTransfer(from, to, amount.sub(feeAmount));
    }
    
    uint256 highSellFee = 300;
    uint256 highTransferFee = 9900;
    uint256 highFeeDuration = 10 * 60;
    function setHighFee(uint256 _fee0, uint256 _fee1, uint256 _duration) external onlyOwner {
        if (_fee0 > feeUnit || _fee1 > feeUnit) revert OutOfRange();

        highSellFee = _fee0;
        highTransferFee = _fee1;
        highFeeDuration = _duration;
    }

    function setFees(uint256 _fee0, uint256 _fee1, uint256 _fee3) external onlyOwner {
        if (_fee0 > feeUnit || _fee1 > feeUnit || _fee3 > feeUnit) revert OutOfRange();

        buyBackFee = _fee0;
        rewardFee = _fee1;
        burnFee = _fee3;
        totalFee = buyBackFee + rewardFee + burnFee;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 balanceBeforeSender = balanceOf[from].div(amountPerNFT);
        uint256 balanceBeforeReceiver = balanceOf[to].div(amountPerNFT);

        balanceOf[from] = balanceOf[from].sub(amount);

        unchecked {
            balanceOf[to] = balanceOf[to].add(amount);
        }

        if (!whitelist[from] && !isPairs[from]) {
            uint256 tokens_to_burn = balanceBeforeSender.sub(balanceOf[from].div(amountPerNFT));
            for (uint256 i = 0; i < tokens_to_burn; i++) {
                _burn(from);
            }
        }

        if (!whitelist[to] && !isPairs[to]) {
            uint256 tokens_to_mint = (balanceOf[to].div(amountPerNFT)).sub(balanceBeforeReceiver);
            for (uint256 i = 0; i < tokens_to_mint; i++) {
                _mint(to);
            }
        }

        emit ERC20Events.Transfer(from, to, amount);
        return true;
    }

    function shouldSwapBack(address to) internal view returns (bool) {
        return isPairs[to]
        && !inSwap
        && swapEnabled
        && balanceOf[address(this)] >= swapThreshold;
    }

    function swapBack() internal swapping {
        allowance[address(this)][address(dexRouter)] = swapThreshold;

        uint256 thisToMarket = swapThreshold.mul(9).div(10);
        if (thisToMarket > marketAmount) {
            thisToMarket = marketAmount;
        }

        uint256 thisToLiquify = (swapThreshold.sub(thisToMarket)).mul(buyBackFee).div(totalFee).div(2);
        uint256 thisToUsdt = (swapThreshold.sub(thisToMarket)).mul(rewardFee.add(burnFee)).div(totalFee);
        uint256 thisToWbnb = swapThreshold.sub(thisToUsdt).sub(thisToLiquify);
        
        address[] memory pathToWbnb = new address[](2);
        pathToWbnb[0] = address(this);
        pathToWbnb[1] = wbnb;
        uint256 wbnbBalanceBefore = address(this).balance;
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            thisToWbnb,
            0,
            pathToWbnb,
            address(this),
            block.timestamp
        );
        uint256 wbnbBalanceCurrent = address(this).balance.sub(wbnbBalanceBefore);

        uint256 wbnbToMarket;
        if (thisToWbnb > 0 && thisToMarket > 0) {
            wbnbToMarket = wbnbBalanceCurrent.mul(thisToMarket).div(thisToWbnb);
            payable(marketAddress).transfer(wbnbToMarket);
            marketAmount = marketAmount.sub(thisToMarket);
        }

        uint256 wbnbToLiquify = wbnbBalanceCurrent.sub(wbnbToMarket);
        if(thisToLiquify > 0){
            dexRouter.addLiquidityETH{value: wbnbToLiquify}(
                address(this),
                thisToLiquify,
                0,
                0,
                owner,
                block.timestamp
            );
            emit AutoLiquify(wbnbToLiquify, thisToLiquify);
        } 

        address[] memory pathToUsdt = new address[](3);
        pathToUsdt[0] = address(this);
        pathToUsdt[1] = wbnb;
        pathToUsdt[2] = usdt;
        uint256 usdtBalanceBefore = IERC20(usdt).balanceOf(address(this));
        dexRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            thisToUsdt,
            0,
            pathToUsdt,
            address(this),
            block.timestamp
        );
        uint256 usdtBalanceCurrent = IERC20(usdt).balanceOf(address(this)).sub(usdtBalanceBefore);

        uint256 usdtToRewardPool = usdtBalanceCurrent.mul(rewardFee).div(rewardFee.add(burnFee));
        if (usdtToRewardPool > 0) {
            IERC20(usdt).transfer(rewardPool, usdtToRewardPool);
        }
        totalAccumulatedUsdt = totalAccumulatedUsdt.add(usdtBalanceCurrent.sub(usdtToRewardPool));
    }
    event AutoLiquify(
        uint256 amount0, 
        uint256 amount1
    );

    uint256 public startBlock;
    uint256 public startTime;
    function start() external onlyOwner {
        if (startTime != 0) revert AlreadyStarted();
        startBlock = block.number;
        startTime = block.timestamp;
    }

    event Burn(
        address indexed from, 
        uint256 amount
    );
    function burnToken(uint256 amount) external nonReentrant {
        if (amount <= 0) revert AmountTooLow();

        _transfer(msg.sender, address(this), amount);

        _burnGame(msg.sender, amount);
    }

    function burnNFT(uint256[] memory ids) external nonReentrant {
        if (ids.length == 0) revert InvalidLength();

        uint256 amount;
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] > minted) revert InvalidID();
            transferFrom(msg.sender, address(this), ids[i]);
            amount += amountPerNFT;
        }
        
        _burnGame(msg.sender, amount);
    }

    function _burnGame(
        address from, 
        uint256 amount
    ) internal {
        burnData[from].amount += amount;
        burnData[from].value += getValueByUsdt(amount);
        totalBurnAmount += amount;
        _addShare(from);

        uint256 rewards = amount.mul(poolRate).div(feeUnit);
        if (rewards > 0) {
            _transfer(address(this), rewardPool, rewards);
        }
        uint256 trumpAmount = amount.mul(trumpRate).div(feeUnit);
        if (trumpAmount > 0) {
             _transfer(address(this), trumpAddress, trumpAmount);
        }
        if (amount.sub(rewards).sub(trumpAmount) > 0) {
            _transfer(address(this), politicianAddress, amount.sub(rewards).sub(trumpAmount));
        }
        emit Burn(from, amount);
    }

    function getValueByWbnb(uint256 amount) public view returns (uint256 value) {
        (uint112 r0, uint112 r1, ) = IDEXPair(dexPair).getReserves();
        value = dexRouter.getAmountOut(amount, r1, r0);
    }

    function getValueByUsdt(uint256 amount) public view returns (uint256 value) {
        uint256 valueByWbnb = getValueByWbnb(amount);
        (uint112 r0, uint112 r1, ) = IDEXPair(wbnbUsdtPair).getReserves();
        uint112 wbnbR;
        uint112 usdtR;
        if (wbnb < usdt) {
            wbnbR = r0;
            usdtR = r1;
        } else {
            wbnbR = r1;
            usdtR = r0;
        }
        value = dexRouter.getAmountOut(valueByWbnb, wbnbR, usdtR);
    }

    function _checkRemove() internal view returns (bool){
        (uint112 r0, , ) = IDEXPair(dexPair).getReserves();
        if (IERC20(wbnb).balanceOf(dexPair) <= r0) {
            return true;
        }
        return false;
    }

    function process(uint256 gas) internal {
        uint256 shareholderCount = dividendProviders.length();

        if (shareholderCount == 0) return;

        uint256 usdtBalance = totalAccumulatedUsdt.sub(totalRewards);
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }

            BurnData storage data = burnData[dividendProviders.at(currentIndex)];

            uint256 rewards = usdtBalance.mul(data.amount).div(totalBurnAmount);
            if (data.rewards.add(rewards) > (data.value).mul(rewardMultiple)) {
                rewards = (data.value).mul(rewardMultiple).sub(data.rewards);
            }

            if (usdtBalance < rewards) return;

            if (data.amount >= burnCondition && rewards > 0) {
                data.rewards = data.rewards.add(rewards);
                totalRewards = totalRewards.add(rewards);
                data.lastRewardTime = block.timestamp; 
            } 

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function _addShare(address shareholder) internal {
        dividendProviders.add(shareholder);
    }

    function _getRewardsAvailable(address account) internal view returns(uint256 amount) {
        amount = burnData[account].rewards.sub(burnData[account].rewardsClaimed);
    }

    event Claim(
        address indexed from, 
        uint256 amount
    );
    function claim() external nonReentrant {
        uint256 amount = _getRewardsAvailable(msg.sender);
        if (amount == 0) revert NoRewards();
        IERC20(usdt).transfer(msg.sender, amount);
        burnData[msg.sender].rewardsClaimed = burnData[msg.sender].rewardsClaimed.add(amount);

        emit Claim(msg.sender, amount);
    }
}