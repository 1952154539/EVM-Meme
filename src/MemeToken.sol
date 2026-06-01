// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MemeToken - ERC20 implementation for minimal proxy clones
/// @notice Each meme token is deployed as an ERC-1167 minimal proxy pointing to this implementation.
///         State is stored in the proxy, while logic is shared via delegatecall.
contract MemeToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply; // 总发行量
    uint256 public perMint; // 每次铸造数量
    uint256 public price; // 每个 token 的价格 (wei)
    uint256 public mintedSupply; // 已铸造数量

    address public issuer; // Meme 发行者
    address public factory; // 工厂合约地址

    bool private _initialized;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @dev Implementation contract constructor locks it from being used directly
    constructor() {
        _initialized = true;
    }

    /// @notice Initializes a cloned proxy with Meme-specific parameters
    /// @dev Can only be called once per proxy
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _issuer,
        address _factory
    ) external {
        require(!_initialized, "Already initialized");
        _initialized = true;

        name = string(abi.encodePacked("Meme ", _symbol));
        symbol = _symbol;
        totalSupply = _totalSupply;
        perMint = _perMint;
        price = _price;
        issuer = _issuer;
        factory = _factory;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    /// @notice Mints perMint tokens to the buyer. Only callable by the factory.
    function mint(address to) external onlyFactory {
        require(mintedSupply + perMint <= totalSupply, "Exceeds total supply");
        mintedSupply += perMint;
        balanceOf[to] += perMint;
        emit Transfer(address(0), to, perMint);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
