pragma solidity ^0.4.20;

// Author: Booyoun Kim
// Date: 8 February 2019
// Version: Lotto v0.1.0

// Changelog
// 

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract Lotto is usingOraclize {

	address owner;
	uint selectedNum;
	bool roundOpen = true;
	uint totalAmount;

	// // 당첨 순위에 따른 당첨자 수
	// uint[3] winnerPersonNumArray = [1, 2, 3];
	// // 순서에 따른 당첨 등수
	// uint[6] winnerRankByOrder = [1, 2, 2, 3, 3, 3];

	Buyer[] public buyers;
	// 1등 1명만 추첨
	Winner[1] public winner;

	// 컨트랙트가 생성되는 순간에 단 한번만 실행된다.
	function Lotto() {
		owner = msg.sender;
		alarm();
	}

    modifier onlyOwner() {
        if (msg.sender == owner) {
            _;
        }
    }

	struct Buyer {
		uint id;
		address addr;
		uint amount;
		uint startIssueNum;
		uint[] issueTickets;
	}

	// 당첨자 기록용
	struct Winner {
		uint winnerId;
		address winnerAddr;
		uint prize;
		uint selectedNum;
	}

	function alarm() private {
		// 60 * 60 * 24 * 30
		// 테스트: 5분 후 게임 종료
    	oraclize_query(60 * 60 * 12 + 23, "URL", "");
    }

    function __callback(bytes32 myid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        // do something, 1 day after contract creation
		closeRound();
    }

	function closeRound() private {
		roundOpen = false;

		// 당첨자 선택
		// 1등
		winner[0].selectedNum 	= getRandomNum(0);
		winner[0].winnerId 		= findBuyerIdBySelectedNum(winner[0].selectedNum);
		winner[0].winnerAddr 	= buyers[winner[0].winnerId].addr;
		winner[0].prize 		= calPrizeForOnePersonByRanking(1);

		// 1등 출금
		withdraw(winner[0].winnerId, winner[0].prize);
		
		// 운영자 출금(남은 잔액 20%)
		owner.transfer(this.balance);
	}

	// 전체 티켓 중 하나 랜덤으로 선택
	function getRandomNum(uint saltNum) constant returns (uint) {
		uint totalTicketNum = getTicketTotalNum();

		// random = uint(sha3(block.timestamp)) % max;		// 0 ~ (max - 1)
		uint random = uint(sha3(block.timestamp - saltNum)) % totalTicketNum + 1;
		return random;
	}

	// 랜덤으로 선택된 추첨 번호표의 buyerId 를 찾는다
	function findBuyerIdBySelectedNum(uint selectedRandomNum) private returns (uint) {
		// selectedRandomNum : 추첨 번호표
		uint selectId;

		for (uint i = 0; i < buyers.length; i++) {
			if (selectedRandomNum > buyers[i].amount / 1000000000000000) {
				selectedRandomNum -= buyers[i].amount / 1000000000000000;
			} else {
				// i 번째가 winner 
				selectId = i;
				break;
			}
		}

		// selectId : 당첨자 id
		return selectId;
	}

	// 상금 계산
	// function calPrizeForOnePersonByRanking(uint ranking) private returns (uint) {
	function calPrizeForOnePersonByRanking(uint ranking) constant returns (uint) {
		// 전체금액의 80%는 상금으로 사용. 나머지 10%는 다음 상금 시드머니로 사용되고 10%는 운영자금으로 사용
		uint prize = this.balance * 8 / 10;

		// if (ranking == 1) {
		// 	prize = amount * 72 / 100;
		// } else if (ranking == 2) {
		// 	prize = amount * 12 / 100;
		// } else if (ranking == 3) {
		// 	// 9% 인데 3명이라서 9/3 = 3
		// 	prize = amount * 3 / 100;
		// } else if (ranking == 4) {
		// 	// 5% 인데 5명이라서 5/5 = 1
		// 	prize = amount * 1 / 100;
		// } else if (ranking == 5) {
		// 	// 2%인데 8명이라서 2/8 = 0.25
		// 	prize = amount * 25 / 10000;
		// }

		return prize;
	}

	// winner 에게 출금
	function withdraw(uint id, uint amount) private {
		if (amount > 0) {
			buyers[id].addr.transfer(amount);
		}
    }

	// 총 티켓 수
	function getTicketTotalNum() constant returns (uint) {
		uint sum = 0;
		if (buyers.length > 0) {
			for (uint i = 0; i < buyers.length; i++) {
				sum += buyers[i].amount / 1000000000000000;
			}
		}
		return sum;
	}

	function getOwner() constant returns (address) {
		return owner;
	}

	function getBuyerAddr(uint buyerId) constant returns (address) {
		return buyers[buyerId].addr;
	}

	function getBuyerAmount(uint buyerId) constant returns (uint) {
		return buyers[buyerId].amount;
	}

	function getBuyerLength() constant returns (uint) {
		return buyers.length;
	}

    function() payable {
    	if (msg.sender == 0x1B17eB8FAE3C28CB2463235F9D407b527ba4e6Dd) {
    		// 운영자가 입금하는 상금
    		return;
    	}

    	// 티켓 1장은 0.001 ETH 이다. 그 미만은 무시된다.
    	if (roundOpen == true && msg.value >= 1000000000000000) {
    		buyers.length += 1;
			uint id = buyers.length - 1;
			
			buyers[id].id 	= id;
			// 기존 티켓 번호표(아래 amount 보다 위에 있어야 한다)
			uint startIssueNum = getTicketTotalNum();
			buyers[id].startIssueNum = startIssueNum;
			buyers[id].addr = msg.sender;
			buyers[id].amount = msg.value;
		}
	}
}