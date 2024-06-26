// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/**
 * @title Gadget shop payment and commissions
 * @author Adeyemi
 * @notice 
 */
contract GadgetShop {
    struct Product {
        bytes32 id;
        string name;
        string features;
        uint256 price;
        address seller;
        bool bought;
    }
    struct Complaint {
        address lodger;
        string productName;
        string complaint;
        string judgement;
        uint256 time;
        bool resolved;
    }
    address public owner;
    mapping (address => uint256) public buyers;
    mapping (address => uint256) public sellers;
    mapping (bytes32 => Product) public products;
    mapping (string => bytes32) public productNames;
    mapping (address => Product) public boughtProduct; // maps buyer to the bought product
    mapping (address => Complaint) public complaints;
    mapping (address => bool) arbitrator;
    uint256 public commission_rate;
    uint256 public commission_total = 0;
    Product[] public productList;
    event Withdrawal(uint amount, uint when);
    event ProductAdded(address seller, string name, bytes32 id, uint256 price);
    event ProductBought(address buyer, address seller, uint256 commission, string productName, bytes32 id);
    event SellerPaid(address seller, uint256 amount);
    event ComplaintLodged(address lodger, string product, string complaint);
    event ComplaintResolved(address lodger, address arbitrator, string product, string judgement);
    event BuyerRefunded(address buyer, string productName, string complaint);


    constructor(uint256 rate) {
        owner = msg.sender;
        commission_rate = rate;
    }

    modifier onlyOwner {
        if (msg.sender != owner) {
            revert("You cannot do this!");
        }
        _;
    }
    modifier onlyArbitrator {
        if (!arbitrator[msg.sender]) {
            revert("You are not an arbitrator!");
        }
        _;
    }

    function withdrawCommission() public onlyOwner {
        payable(owner).transfer(commission_total);
        emit Withdrawal(commission_total, block.timestamp);
    }

    /**
     * adds an arbitrator
     */
    function addArbitrator() public {
        arbitrator[msg.sender] = true;
    }

    /**
     * Adds a product to the contract
     * @param name name of product
     * @param features features of the product
     * @param price price of the product
     * @param seller seller's address
     */
    function addProduct(string memory name, string memory features, uint256 price, address seller) public returns(bytes32) {
        bytes32 id = generateID(name, seller);
        Product memory item = Product(id, name, features, price, seller, false);
        products[id] = item;
        productNames[name] = id;
        productList.push(item);
        emit ProductAdded(seller, name, id, price);
        return id;
    }
    /**
     * creates a bytes32 array from two strings
     * @param str1 first string
     * @param str2 second string
     */
    function generateID(string memory str1, address str2) public pure returns (bytes32) {
        return(keccak256(abi.encodePacked(str1, str2)));
    }

    /**
     * Take commission on payment
     * @param amount price of product
     * @param seller srller's address
     */
    function takeCommission(uint256 amount, address seller) internal returns(uint256) {
        uint256 commission = (amount * commission_rate) / 100;
        sellers[seller] += amount - commission;
        commission_total += commission;
        return (commission);
    }

    /**
     * Pay money for product
     * @param name name of the product
     */
    function buyProduct(string memory name) public payable {
        bytes32 _id = productNames[name];
        if (_id[0] == 0) {
            revert("Product does not exist");
        }
        Product memory item = products[_id];
        if (item.seller != address(0) && item.price == 0) {
            revert ("Product does not exist");
        }
        if (msg.value < item.price) {
            revert("Insufficient funds");
        }
        uint256 commission = takeCommission(msg.value, item.seller);
        products[_id].bought = true;
        boughtProduct[msg.sender] = products[_id];
        emit ProductBought(msg.sender, item.seller, commission, item.name, _id);
    }

    /**
     * owner withdraws money
     */
    function withdraw() public payable onlyOwner {
        if (address(this).balance > 0) {
            revert("You should have more money");
        }
        payable(owner).transfer(address(this).balance);
        emit Withdrawal(address(this).balance, block.timestamp);
    }

    /**
     * Lodges a complaint
     * @param product_name name of the product
     * @param complaint complaint
     * emits [ComplaintLodged] event
     */
    function lodgeComplaint(string memory product_name, string memory complaint) public {
        Complaint memory complain = Complaint(msg.sender, product_name, complaint, "", block.timestamp, false);
        complaints[msg.sender] = complain;
        emit ComplaintLodged(msg.sender, product_name, complaint);
    }

    /**
     * Complaint resolving
     * @param buyer complainer
     * @param judgement arbitrator's judgement
     */
    function resolveComplaint(address buyer, string memory judgement) public onlyArbitrator {
        complaints[buyer].judgement = judgement;
        complaints[buyer].resolved = true;
        emit ComplaintResolved(buyer, msg.sender, complaints[buyer].productName, judgement);
    }

    function returnBuyerFunds(address buyer, string memory judgement) public onlyArbitrator {
        Complaint memory complain = complaints[buyer];
        complain.judgement = judgement;
        complain.resolved = true;
        complaints[buyer] = complain;
        uint256 amt = products[productNames[complain.productName]].price;
        payable(buyer).transfer(amt);
        uint256 commission = (amt * commission_rate) / 100;
        sellers[products[productNames[complain.productName]].seller] -= amt - commission;
        commission_total -= commission;
        products[productNames[complain.productName]].bought = false;
        emit BuyerRefunded(buyer, complain.productName, complain.complaint);
    }

    /**
     * Pay payable seller
     */
    function paySeller() public {
        if (sellers[msg.sender] == 0) {
            revert("You are not a seller or we do not have your money");
        }
        payable(msg.sender).transfer(sellers[msg.sender]);
        emit SellerPaid(msg.sender, sellers[msg.sender]);
        sellers[msg.sender] = 0;
    }
}
