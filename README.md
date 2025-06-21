# Cross-chain Rebase Token

1. A protocol that allows user to deposit into a vault and in return receive rebase tokens that represent their underlying balance.
2. Rebase token -> balanceOf function is dynamic ti show the chaning balance with time.
    - Balance increases linearly with time
    - mint tokens to our users everytime they perform an action (minting, burning, transferring, or.... bridging)
3. Interest rate
    - Individually set an interest rate for each user based on some global interest rate ofg the protocol at the same time the user deposits into the vault
    - This global interest can be decreased to incentivise early adopters
