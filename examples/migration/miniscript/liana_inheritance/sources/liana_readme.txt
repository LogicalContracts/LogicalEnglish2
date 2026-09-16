Liana README (https://github.com/wizardsardine/liana, BSD-3-Clause), section About, retrieved 2026-09-13.

## About

Liana is a simple Bitcoin wallet. Like other Bitcoin wallets you have one key which can spend the
funds in the wallet immediately. Unlike other wallets, Liana lets you in addition specify one key
which can only spend the coins after the wallet has been inactive for some time.

We refer to these as the primary spending path (always accessible) and the recovery path (only
available after some time of inactivity). You may have more than one key in either the primary or
the recovery path (multisig). You may have more than one recovery path.

Here is an example of a Liana wallet configuration:
- Wallet Manager's key (can always spend)
- Any 2 keys from the owner's spouse and two kids (after 1 year)
- A third party, in case [all else failed](https://wizardsardine.com/liana/plans#section-safety-net)
  (after 1 year and 3 months)

The lockup period is enforced onchain by the Bitcoin network. This is achieved by leveraging
timelock capabilities of Bitcoin smart contracts (Script).

Liana can be used for **trustless inheritance**, **loss protection** or **safer backups**. Visit
[our website](https://wizardsardine.com/liana) for more information.
