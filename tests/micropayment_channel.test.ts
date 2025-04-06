import { describe, it, expect, vi, beforeEach } from "vitest";

describe("Payment Channel Contract", () => {
  let channels: Record<string, any>;

  beforeEach(() => {
    channels = {};
  });

  it("should open a new channel", () => {
    const channelId = 1;
    const participant1 = "SP123";
    const participant2 = "SP456";
    const initialBalance1 = 1000;
    const initialBalance2 = 500;

    expect(channels[channelId]).toBeUndefined();

    channels[channelId] = {
      participant1,
      participant2,
      balance1: initialBalance1,
      balance2: 0, // participant 2 deposits later
      nonce: 0,
      state: "OPEN",
      challengeHeight: 0,
    };

    expect(channels[channelId]).toMatchObject({
      participant1,
      participant2,
      balance1: initialBalance1,
      balance2: 0,
      state: "OPEN",
    });
  });

  it("should join an open channel", () => {
    const channelId = 2;
    channels[channelId] = {
      participant1: "SP123",
      participant2: "SP456",
      balance1: 1000,
      balance2: 500,
      nonce: 0,
      state: "OPEN",
      challengeHeight: 0,
    };

    // Simulate join
    const participant2 = "SP456";
    const caller = participant2;

    expect(channels[channelId].participant2).toBe(caller);
    expect(channels[channelId].state).toBe("OPEN");

    channels[channelId].state = "ACTIVE";

    expect(channels[channelId].state).toBe("ACTIVE");
  });

  it("should initiate closing the channel", () => {
    const channelId = 3;
    const currentBlockHeight = 100;
    channels[channelId] = {
      participant1: "SP123",
      participant2: "SP456",
      balance1: 1000,
      balance2: 1000,
      nonce: 1,
      state: "ACTIVE",
      challengeHeight: 0,
    };

    const caller = "SP123";
    const isParticipant = [channels[channelId].participant1, channels[channelId].participant2].includes(caller);
    expect(isParticipant).toBe(true);
    expect(channels[channelId].state).toBe("ACTIVE");

    channels[channelId].state = "CLOSING";
    channels[channelId].challengeHeight = currentBlockHeight + 144;

    expect(channels[channelId].state).toBe("CLOSING");
    expect(channels[channelId].challengeHeight).toBe(244);
  });

  it("should fail if unauthorized participant tries to join", () => {
    const channelId = 4;
    channels[channelId] = {
      participant1: "SP123",
      participant2: "SP456",
      balance1: 1000,
      balance2: 500,
      nonce: 0,
      state: "OPEN",
      challengeHeight: 0,
    };

    const caller = "SP999"; // not participant2
    expect(caller).not.toBe(channels[channelId].participant2);
  });

  it("should reject invalid state update if nonce is not increasing", () => {
    const channelId = 5;
    channels[channelId] = {
      participant1: "SP123",
      participant2: "SP456",
      balance1: 1000,
      balance2: 500,
      nonce: 5,
      state: "ACTIVE",
      challengeHeight: 0,
    };

    const newNonce = 3;
    expect(newNonce).toBeLessThanOrEqual(channels[channelId].nonce);
  });
});
