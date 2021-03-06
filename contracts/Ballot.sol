pragma solidity >= 0.6.2 < 0.7.0;
import "./Owned.sol";
import "./StandardToken.sol";
import "./Authority.sol";
import "./Controlled.sol";
//投票合约
contract Ballot is StandardToken,
Controlled,
Authority {
    //合约创建的时候执行，执行合约的人是第一个owner
    constructor() public {
        //	owner = msg.sender;
    }
    //ballot
    struct Voter {
        uint256 weight; // this time don't use,weight is accumulated by delegation，
        bool voted; //if true ,that perpn already voted
        uint vote;
        address delegate;
    }
    struct Proposal {
        uint voteCount;
        string describle;
        bool truefalse;
    }
    address public chairPerson;
    mapping(address =>Voter) public voters;
    Proposal[] public proporsals; //index0 = true;index1 = false;

    struct proporsalsresults {
        uint voteCount;
        string describle;
        bool truefalse;
        uint looservoteCount;
    }
    mapping(uint256 =>proporsalsresults) public proporsalsresultslist;
    uint256 public proporsalsresultslength = 0;
    uint256 public votestarttime = 0; //每次结束投票时间,初始值24小时,
    uint256 public voteendtime = 86400; //每次结束投票时间,初始值24小时,
    bool public iflastvotefinish = true; //上次投票是否结束,true=结束,false=投票中
    //投票发起时间点，所有地址持币值快照
    mapping(address =>uint256) public balanceAtVoteTime;
    // 要求投票用户持币DGE > 一定数量 初始值=0；
    uint256 public voteLessDGEAmount = 0;
    //控制合约 要求投票用户持币DGE > 一定数量 初始值=0；
    modifier voteRightLesDGEAmount() {
        require((balanceOf[msg.sender] >= voteLessDGEAmount), "There is no right to vote，the minimum amount of COINS is not reached!");
        _;
    }
    //设置每次结束投票时间,初始值24小时,;强制设置,上次投票是否结束,true=结束,false=投票中
    function setVoteendtime(uint256 _voteendtime, bool _iflastvotefinish) public onlyGovenors1 returns(bool _success) {
        voteendtime = _voteendtime;
        iflastvotefinish = _iflastvotefinish;
        return true;
    }
    //投票发起时间点，所有地址持币值快照,所有地址Voter数据清零, 其他投票数据全部清零
    function voteWriteAllBalance() internal onlyOwner {
        //proporsals.length = 0;
        delete proporsals;
        for (uint i = 1; i <= addrListLength; i++) {
            uint256 nowVoteBalance = balanceOf[addrList[i]];
            balanceAtVoteTime[addrList[i]] = nowVoteBalance;
            voters[addrList[i]].weight = 0;
            voters[addrList[i]].voted = false;
            voters[addrList[i]].vote = 0;
            voters[addrList[i]].delegate = address(0);
        }
    }
    uint voteCount;
    string describle;
    string data;
    //发起投票
    function makeAVote(string memory _describle) public voteLockAllowed {
        require(iflastvotefinish == true, "myvote error : last vote still running");
        iflastvotefinish = false;
        votestarttime = block.timestamp;
        chairPerson = owner;
        voteWriteAllBalance();
        voters[chairPerson].weight = balanceAtVoteTime[chairPerson];
        proporsalsresultslength += 1;
        proporsals[0].voteCount = 0;
        proporsals[0].describle = _describle;
        proporsals[0].truefalse = true;

        proporsals[1].voteCount = 0;
        proporsals[1].describle = _describle;
        proporsals[1].truefalse = false;
    }
    /**
	//_weight,大小为币的数量，单位为最小单位
	function giveRightToVote(address to, uint256 _weight) public {
		require(msg.sender == chairPerson, "Only chairperson can give right to vote.");
		require(!voters[to].voted, "The voter already voted.");
		//	require(voters[to].weight == 0);
		//	voters[to].weight = _weight;
		balanceAtVoteTime[to] = balanceAtVoteTime[to].add(_weight);
	}
	*/
    //委托
    function delegate(address to) public voteRightLesDGEAmount {
        require(iflastvotefinish == false, "myvote error :  no vote runing right now");
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "you hava already voted");
        require(to != msg.sender);
        while (voters[to].delegate != address(0) && voters[to].delegate != msg.sender) {
            to = voters[to].delegate;
        }
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegateTo = voters[to];
        if (delegateTo.voted) {
            proporsals[delegateTo.vote].voteCount = proporsals[delegateTo.vote].voteCount.add(balanceAtVoteTime[msg.sender]);
        } else {
            balanceAtVoteTime[to] = balanceAtVoteTime[to].add(balanceAtVoteTime[msg.sender]);
        }
    }
    //从数组0号开始
    function vote(uint proposal) public voteRightLesDGEAmount voteLockAllowed {
        require(iflastvotefinish == false, "myvote error :  no vote runing right now");
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "no right");
        sender.voted = true;
        sender.vote = proposal;
        proporsals[sender.vote].voteCount = proporsals[sender.vote].voteCount.add(balanceAtVoteTime[msg.sender]);
    }

    //目前获胜编号
    function winningProposal() public view returns(uint _winningProposal) {
        require(iflastvotefinish == false, "myvote error :  no vote runing right now");
        uint winningCount = 0;
        for (uint prop = 0; prop < proporsals.length; prop++) {
            if (winningCount < proporsals[prop].voteCount) {
                winningCount = proporsals[prop].voteCount;
                _winningProposal = prop;
            }
        }
    }
    //获胜者票数
    function winningCount(uint) view public returns(uint256) {
        require(iflastvotefinish == false, "myvote error :  no vote runing right now");
        uint _winningCount = 0;
        uint _winningProposal = 0;
        for (uint prop = 0; prop < proporsals.length; prop++) {
            if (_winningCount < proporsals[prop].voteCount) {
                _winningCount = proporsals[prop].voteCount;
                _winningProposal = prop;
            }
        }

        return proporsals[_winningProposal].voteCount.div(10 **uint256(decimals));
    }
    //各个编号票数
    function thisOneCount(uint _index) view public returns(uint256) {
        return proporsals[_index].voteCount.div(10 **uint256(decimals));
    }
    //结束本次投票,写入获胜结果列表
    function writeThisVoteResult() public returns(bool _success) {
        require(iflastvotefinish == false, "myvote error :  no vote runing right now");
        require(block.timestamp >= (votestarttime + voteendtime), "myvote error : last vote do not reach finish time");
        iflastvotefinish = true;
        uint256 winnerindex = winningProposal();
        uint256 winnerGetCount = winningCount(winnerindex);
        proporsalsresultslist[proporsalsresultslength].voteCount = winnerGetCount;
        proporsalsresultslist[proporsalsresultslength].describle = proporsals[winnerindex].describle;
        proporsalsresultslist[proporsalsresultslength].truefalse = proporsals[winnerindex].truefalse;
        if (winnerindex == 0) {
            proporsalsresultslist[proporsalsresultslength].looservoteCount = proporsals[1].voteCount;
        } else {
            proporsalsresultslist[proporsalsresultslength].looservoteCount = proporsals[0].voteCount;
        }
        // proporsals.length=0;
        delete proporsals;
        return true;
    }
    //查询获胜结果列表,index查询
    function getVoteResultByIndex(uint256 _index) public returns(uint _voteCount, string memory _describle, bool _truefalse, uint _looservoteCount) {
        _voteCount = proporsalsresultslist[_index].voteCount;
        _describle = proporsalsresultslist[_index].describle;
        _truefalse = proporsalsresultslist[_index].truefalse;
        _looservoteCount = proporsalsresultslist[_index].looservoteCount = proporsals[0].voteCount;
        // proporsals.length=0;
        delete proporsals;
        return (_voteCount, _describle, _truefalse, _looservoteCount);
    }
}