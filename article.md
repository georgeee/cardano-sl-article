# Delegation in Cardano SL

## Requirements

We need a delegation scheme for Cardano SL. This scheme:

1.  Should allow us to delegate/redelegate/revoke rights on stake owned by user.
2.  Shouldn't require to expose public key on which money are kept to perform delegation.
3.  Should be easy to integrate with HD wallets, i.e. to easily delegate from
    all keys of HD wallet tree/subtree to somebody.

The important concern is the fact that new address' types can be introduced via softfork in the future,
and we don't know in advance about semantics of these types.

## Original Scheme

The concept of delegation is simple: any stakeholder can allow a delegate to generate blocks on her
behalf. In the context of our protocol, where a slot leader signs the block it generates for a certain
slot, such a scheme can be implemented in a straightforward way based on proxy signatures.
A stakeholder can transfer the right to generate blocks by creating a proxy signing key that
allows the delegate to sign messages of the form _$(st, d, sl_j)$_ (i.e., the format of messages signed in
Protocol $\pi\textsubscript{DPoS}$ to authenticate a block). Protocol $\pi\textsubscript{DPoS}$ is
described in [Ouroboros paper](https://eprint.iacr.org/2016/889.pdf), page _$[33]$_. In order to limit
the delegate’s block generation power to a certain range of epochs/slots, the stakeholder can limit the
proxy signing key’s valid message space to strings ending with a slot number _$sl_j$_ within a specific
range of values. The delegate can use a proxy signing key from a given stakeholder to simply run
Protocol $\pi\textsubscript{DPoS}$ on her behalf, signing the blocks this stakeholder was elected to
generate with the proxy signing key.

This scheme is secure due to the _Verifiability and Prevention of Misuse_ properties of proxy
signature schemes, which ensure that any stakeholder can verify that a proxy signing key was actually
issued by a specific stakeholder to a specific delegate and that the delegate can only use these keys
to sign messages inside the key’s valid message space, respectively. _Verifiability and Prevention of Misuse_
is described in the [paper](https://eprint.iacr.org/2003/096.pdf)
“Secure Proxy Signature Schemes for Delegation of Signing Rights”, page _$[2]$_.

We remark that while proxy signatures can be described as a high level generic primitive, it is easy
to construct such schemes from standard digital signature schemes through delegation-by-proxy. In this
construction, a stakeholder signs a certificate specifying the delegates identity (e.g., its public key)
and the valid message space. Later on, the delegate can sign messages within the valid message
space by providing signatures for these messages under its own public key along with the signed
certificate. As an added advantage, proxy signature schemes can also be built from aggregate
signatures in such a way that signatures generated under a proxy signing key have essentially the
same size as regular signatures.

An important consideration in the above setting is the fact that a stakeholder may want to
withdraw her support to a stakeholder prior to its proxy signing key expiration. Observe that proxy
signing keys can be uniquely identified and thus they may be revoked by a certificate revocation
list within the blockchain.

### Eligibility Threshold

Delegation as described above can ameliorate fragmentation that may occur in the stake distribution.
Nevertheless, this does not prevent a malicious stakeholder from dividing its stake to multiple
accounts and, by refraining from delegation, induce a very large committee size. To address this,
as mentioned above, a threshold _$T$_, say 1%, may be applied. This means that any delegate representing
less a fraction less than _$T$_ of the total stake is automatically barred from being a committee
member. This can be facilitated by redistributing the voting rights of delegates representing less
than _$T$_ to other delegates in a deterministic fashion (e.g., starting from those with the highest stake
and breaking ties according to lexicographic order).

Suppose that a committee has been formed, $C_1, ..., C_m$, from a total of _$k$_ draws of weighing by stake.
Each committee member will hold _$k_i$_ such votes where $\sum\limits_{i=1}^m k_i = k$. Based on the
eligibility threshold above it follows that _$m \leq T−1$_ (the maximum value is the case when all stake is
distributed in _$T−1$_ delegates each holding _$T$_ of the stake).

## Original Scheme Implementation

The original scheme of delegation is implemented in Cardano SL by two different delegation types:
heavyweight delegation and lightweight delegation.

### Heavyweight Delegation

Heavyweight delegation is using stake threshold _$T$_. It means that stakeholder
has to posses not less than _$T$_ in order to participate in heavyweight
delegation. The value of this threshold is defined in the [configuration file](https://github.com/input-output-hk/cardano-sl/blob/d01d392d49db8a25e17749173ec9bce057911191/core/constants.yaml#L22).

Moreover, the issuer stakeholder must have particular amount of stake too, otherwise [it
cannot
be](https://github.com/input-output-hk/cardano-sl/blob/763822c4fd906f36fa97b6b1f973d31d52342f3f/src/Pos/Delegation/Logic/VAR.hs#L394)
a valid issuer.

Proxy signing certificates from heavyweight delegation are stored within the
blockchain. Please note that issuer can post [only one
certificate](https://github.com/input-output-hk/cardano-sl/blob/763822c4fd906f36fa97b6b1f973d31d52342f3f/src/Pos/Delegation/Logic/VAR.hs#L401)
per one epoch.

### Lightweight Delegation

In contrast to heavyweight delegation, lightweight delegation doesn't require
that delegate posses _$T$_-or-more stake. So lightweight delegation is available
for any node. But proxy signing certificates for lightweight delegation are not
stored in the blockchain, so lightweight delegation certificate must be broadcasted
to reach delegate.

Later lightweight PSK can be
[verified](https://github.com/input-output-hk/cardano-sl/blob/9d7be20eeafac27e682551d05f4aba2faba537bc/src/Pos/Delegation/Logic/Mempool.hs#L285)
given issuer's public key, signature and message itself.

## Original Scheme Drawbacks

Current implementation of delegation scheme described below uses proxy signing key scheme, which
itself requires a public key being associated with stakeholder and used to sign delegation.
Initially it was thought this public key to be an actual key which holds money, but this decreases
security by exposing public key of address before spending money from it. We propose a solution
for this concern.

## Modified Delegation Proposal

### Modified Delegation Proposal Analysis

As careful reader may observe, when transaction with transaction distribution is being sent, money
are sent to the key _$K$_, but _$D$_ is responsible for delegation. This way if even _$D$_ public
component will be exposed (which is case when we would like to delegate with certificate), _$K$_'s
public key won't be exposed till money are sent. This satisfies requrement 2.

Section **Usage with HD Wallets** descirbes how we satisfy requirement 3.

### Transaction Distribution

Transaction distribution is another part of Cardano SL, not directly related to delegation,
but one we can exploit for its benefit.

Some addresses have multiple owners, which poses a problem of stake computation as per
Follow-the-Satoshi each coin should only be counted once towards each stakeholder's stake total.
Unlike balance (real amount of coins on the balance), stake gives user power to control different
algorithm parts: being the slot leader, voting in Update system, taking part in MPC/SSC.

Suppose we have an address _$A$_. If it is a [`PublicKey`](https://cardanodocs.com/cardano/addresses/)-address
it's obvious and straightforward which stakeholders should benefit from money stored on this address,
though it's not for [`ScriptAddress`](https://cardanodocs.com/cardano/addresses/) (e.g. for `2-of-3` multisig
address implemented via script we might want to have distribution
_$[(A, 1/3), (B, 1/3), (C, 1/3)]$_). For any new address' type introduced via
softfork in the future it might be useful as well because we don't know in
advance about semantics of the new address' type and which stakeholder it should
be attributed to.

Transaction distribution is a value associated with each transaction's output,
holding information on which stakeholder should receive which particular amount
of money on his stake. Technically it's a list of pairs composed from stakeholder's
identificator and corresponding amount of money. E.g. for output `(A, 100)`
distribution might be _$[(B, 10), (C, 90)]$_.

Transaction distributions are considered by both [slot-leader election
process](https://cardanodocs.com/technical/leader-selection/) and Richmen Computations.

This feature is very similar to [delegation](https://cardanodocs.com/technical/delegation/), but there
are differences:

1.  There is no certificate(s): to revoke delegation _$A$_ has to move funds,
    providing different distribution.
2.  Only part of _$A$_'s balance associated with this transaction output is delegated.
    This can be done in chunks per balance parts (on contrary, delegation requires you
    to delegate all funds of whole address at once).

By consensus, transaction distribution for `PublicKey`-address should be set to
empty.

### Protocol Participation Keys and Spending Keys

Transaction distribution is a practical way to split spending keys and protocol participation
keys. Protocol participation keys allow to control stake, associated with transaction output.

In transaction output we specify spending key data. Thus:

* for `PublicKey`-address we specify spending key hash,
* for `Script`-address some spending key will be used within script probably.

Let's consider basic use case. We want user _$U$_ to send _$v$_ coins to our address _$R$_. Then
we find transaction _$U \rightarrow R$_ in the blockchain, which shows us money were sent.
We call _$R$_ a _receiving_ address.

Let's assume we have two more addresses:

1.  _$K$_, _keeper_ address,
2.  _$D$_, _delegator_ address.

Next we form a new transaction _$R \rightarrow K$_ (sending all _$v$_ coins from _$R$_ to _$K$_)
with `txDistr = [(D, v)]`. After this transaction will be processed, funds would be contained on
address _$K$_, but the right to issue blocks and participate in slot leader election would be held
by _$D$_. This way we effectively decoupled key which controls money and key which is used for
protocol maintenance.

### Usage with HD Wallets

For HD wallets, we reserve _$(root, 0)$_ key as a delegator. We use _$(root, k > 1, 2 * i)$_
keys as receiving addresses and _$(root, k > 1, 2 * i + 1)$_ keys as keepers.

Delegation or redelegation of the whole HD wallet structure then is as simple as issuing
a single lightweight/heavyweight certificate for an address `(root, 0)`.

# Stake Locking in Cardano SL

The Bootstrap era is the period of Cardano SL existence that allows only fixed predefined
users to have control over the system. The set of such users (the bootstrap stakeholders)
and propotion of total stake each of them controls is defined in genesis block.

Purpose of Bootstrap era is to address concern that at the beginning of mainnet majority of
stake will probably be offline (which protocol broken at start). Bootstrap era is to be ended
when network stabilizes and majority of stake is present online.

The next era after Bootstrap is called [the Reward era](https://cardanodocs.com/timeline/reward/).
Reward era is actually a "normal" operation mode of Cardano SL as a PoS-cryptocurrency.

## Requirements

1.  During Bootstrap era stake in Cardano SL should be effectively delegated to a fixed set of keys _$S$_.
2.  _$|S| \leq 3$_
3.  Stake should be distributed among _$s \in S$_ in fixed predefined propotion, e.g. _$2:5:3$_.
4.  At the end of Bootstrap era stake should be unlocked:
    1.  Ada buyers should be able to participate in protocol themselves (or delegate their rights to some
        delegate not from _$S$_).
    2.  Each Ada buyer should explicitly state she wants to take control over her stake.
        * Otherwise it may easily lead to situation when less than majority of stake is online once Reward
        era starts.
    3.  Before this withdrawing stake action occurs, stake should be still being controlled by _$S$_ nodes.
    4.  _(Optional)_ Stake transition during unlocking should be free for user.

## Proposal

Let us now present the Bootstrap era solution:

1.  Initial `utxo` contains all the stake distributed among `gcdBootstrapStakeholders`. Initial `utxo`
    consists of `(txOut, txOutDistr)` pairs, so we just set` txOutDistr` in a way it sends all coins
    to `gcdBootstrapStakeholders` in proportion specified in genesis block.
2.  While the Bootstrap era takes place, users can send transactions changing initial `utxo`. We enforce
    setting `txOutDistr` for each transction output to spread stake to `gcdBootstrapStakeholders` in
    proportion specified by genesis block. This effectively makes stake distribution is system constant.
3.  When the Bootstrap era is over, we disable restriction on `txOutDistr`. Bootstrap stakeholders will
    vote for Bootstrap era ending: special update proposal will be formed, where a particular constant
    will be set appropriately to trigger Bootstrap era end at the point update proposal gets adopted.
    System operates the same way as in Bootstrap era, but users need to explicitly state they understand
    owning their stake leads to responsibility to handle the node. For user to get his stake back he should
    send a transaction to delegate key(s). It may be the key owned by user himself or the key of some delegate
    (which may also be one or few of `gcdBootstrapStakeholders`).

### Multiple Nodes with Same Key

To reduce the size of transactions, we want to have set of bootstrap stakeholder as small as possible. In
principle it should be as small as number of actual parties involved (e.g. IOHK, CGG, CF each holding single key).

This way it's handy to have secret key _$s \in gcdBootstrapStakeholders$_ can be distributed accross multiple
nodes (because usual case is you want to have multiple nodes operating in different data centers to provide
reliable service).

Simplest proposal to distribute key accross multiple nodes would be to run multiple nodes with the same secret key
and have them participating in the algorithm in round-robin fashion, in particular:

1.  Create blocks in predefined order. If key is a slot leader for _$slot_1$_, _$slot_3$_ and _$slot_5$_,
    then _$node_0$_ creates block at _$slot_1$_, _$node_1$_ - at _$slot_3$_, and _$node_2$_ - at _$slot_5$_.
2.  Create MPC payloads accurately. If key is obliged to post _$M$_ commitments, openings, shares,
    then _$node_0$_, _$node_1$_ and _$node_2$_ will post _$\frac{M}{3}$_ each.

### Free Transaction for Bootstrap Era

Delegating stake back is done via transaction. But transactions cost money (via fees), which violates requirement
`4.4` (which is marked as an optional, but yet desirable).

As a solution to this issue we could make a snapshot of utxo _$U$_ at the moment Bootstrap era ends and don't
require fees to be withdrawn from any transaction output, contained in _$U$_. This will effectively make delegation
transition transaction free.
