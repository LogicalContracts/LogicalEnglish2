# Migration ledger: anti_social

Source: an L4 program (smucclaw/l4-ide) — anti-social.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 12 |
| approximated | 12 |
| residue | 0 |
| **total** | 24 |

Fidelity: **128 of 128** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| is authorised | wording | approximated | the template's words made from the name, its inputs appended | *a person* is authorised | to be reviewed: the name does not say where its inputs go |
| is an individual aged 16 or over | wording | approximated | the template's words made from the name, its inputs appended | *a receiver* is an individual aged 16 else over | to be reviewed: the name does not say where its inputs go |
| is a body | wording | approximated | the template's words made from the name, its inputs appended | *a receiver* is a body | to be reviewed: the name does not say where its inputs go |
| is detrimental | wording | approximated | the template's words made from the name, its inputs appended | *an effect* is detrimental | to be reviewed: the name does not say where its inputs go |
| is of a persistent or continuing nature | wording | approximated | the template's words made from the name, its inputs appended | *an effect* is of a persistent else continuing nature | to be reviewed: the name does not say where its inputs go |
| affects the quality of life of those in the locality | wording | approximated | the template's words made from the name, its inputs appended | *an effect* affects the quality of life of those in the locality | to be reviewed: the name does not say where its inputs go |
| conduct | wording | approximated | the template's words made from the name, its inputs appended | the conduct for *a receiver* is *a conduct* | to be reviewed: the name does not say where its inputs go |
| effect | wording | approximated | the template's words made from the name, its inputs appended | the effect for *a conduct* is *an effect* | to be reviewed: the name does not say where its inputs go |
| is unreasonable | wording | approximated | the template's words made from the name, its inputs appended | *a conduct* is unreasonable | to be reviewed: the name does not say where its inputs go |
| may issue a community protection notice | wording | approximated | the template's words made from the name, its inputs appended | *a person* may issue a community protection notice for *a receiver* | to be reviewed: the name does not say where its inputs go |
| is authorised | assume | encoded | a template the scenarios state (; undefined) | is authorised |  |
| is an individual aged 16 or over | assume | encoded | a template the scenarios state (; undefined) | is an individual aged 16 or over |  |
| is a body | assume | encoded | a template the scenarios state (; undefined) | is a body |  |
| is detrimental | assume | encoded | a template the scenarios state (; undefined) | is detrimental |  |
| is of a persistent or continuing nature | assume | encoded | a template the scenarios state (; undefined) | is of a persistent or continuing nature |  |
| affects the quality of life of those in the locality | assume | encoded | a template the scenarios state (; undefined) | affects the quality of life of those in the locality |  |
| conduct | assume | encoded | a template the scenarios state (; undefined) | conduct |  |
| effect | assume | encoded | a template the scenarios state (; undefined) | effect |  |
| is unreasonable | assume | encoded | a template the scenarios state (; undefined) | is unreasonable |  |
| the conduct | wording | approximated | the template's words made from the name, its inputs appended | the conduct in may issue a community protection notice for *a receiver* variant one is *a conduct* | to be reviewed: the name does not say where its inputs go |
| the effect | wording | approximated | the template's words made from the name, its inputs appended | the effect in may issue a community protection notice for *a receiver* variant two is *an effect* | to be reviewed: the name does not say where its inputs go |
| the conduct | definition | encoded | func | the conduct in may issue a community protection notice for *a receiver* variant one is *a conduct* |  |
| the effect | definition | encoded | func | the effect in may issue a community protection notice for *a receiver* variant two is *an effect* |  |
| may issue a community protection notice | definition | encoded | pred | *a person* may issue a community protection notice for *a receiver* |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| variant_1 | may_issue_a_community_protection_notice | pass |  |
| variant_2 | may_issue_a_community_protection_notice | pass |  |
| variant_3 | may_issue_a_community_protection_notice | pass |  |
| variant_4 | may_issue_a_community_protection_notice | pass |  |
| variant_5 | may_issue_a_community_protection_notice | pass |  |
| variant_6 | may_issue_a_community_protection_notice | pass |  |
| variant_7 | may_issue_a_community_protection_notice | pass |  |
| variant_8 | may_issue_a_community_protection_notice | pass |  |
| variant_9 | may_issue_a_community_protection_notice | pass |  |
| variant_10 | may_issue_a_community_protection_notice | pass |  |
| variant_11 | may_issue_a_community_protection_notice | pass |  |
| variant_12 | may_issue_a_community_protection_notice | pass |  |
| variant_13 | may_issue_a_community_protection_notice | pass |  |
| variant_14 | may_issue_a_community_protection_notice | pass |  |
| variant_15 | may_issue_a_community_protection_notice | pass |  |
| variant_16 | may_issue_a_community_protection_notice | pass |  |
| variant_17 | may_issue_a_community_protection_notice | pass |  |
| variant_18 | may_issue_a_community_protection_notice | pass |  |
| variant_19 | may_issue_a_community_protection_notice | pass |  |
| variant_20 | may_issue_a_community_protection_notice | pass |  |
| variant_21 | may_issue_a_community_protection_notice | pass |  |
| variant_22 | may_issue_a_community_protection_notice | pass |  |
| variant_23 | may_issue_a_community_protection_notice | pass |  |
| variant_24 | may_issue_a_community_protection_notice | pass |  |
| variant_25 | may_issue_a_community_protection_notice | pass |  |
| variant_26 | may_issue_a_community_protection_notice | pass |  |
| variant_27 | may_issue_a_community_protection_notice | pass |  |
| variant_28 | may_issue_a_community_protection_notice | pass |  |
| variant_29 | may_issue_a_community_protection_notice | pass |  |
| variant_30 | may_issue_a_community_protection_notice | pass |  |
| variant_31 | may_issue_a_community_protection_notice | pass |  |
| variant_32 | may_issue_a_community_protection_notice | pass |  |
| variant_33 | may_issue_a_community_protection_notice | pass |  |
| variant_34 | may_issue_a_community_protection_notice | pass |  |
| variant_35 | may_issue_a_community_protection_notice | pass |  |
| variant_36 | may_issue_a_community_protection_notice | pass |  |
| variant_37 | may_issue_a_community_protection_notice | pass |  |
| variant_38 | may_issue_a_community_protection_notice | pass |  |
| variant_39 | may_issue_a_community_protection_notice | pass |  |
| variant_40 | may_issue_a_community_protection_notice | pass |  |
| variant_41 | may_issue_a_community_protection_notice | pass |  |
| variant_42 | may_issue_a_community_protection_notice | pass |  |
| variant_43 | may_issue_a_community_protection_notice | pass |  |
| variant_44 | may_issue_a_community_protection_notice | pass |  |
| variant_45 | may_issue_a_community_protection_notice | pass |  |
| variant_46 | may_issue_a_community_protection_notice | pass |  |
| variant_47 | may_issue_a_community_protection_notice | pass |  |
| variant_48 | may_issue_a_community_protection_notice | pass |  |
| variant_49 | may_issue_a_community_protection_notice | pass |  |
| variant_50 | may_issue_a_community_protection_notice | pass |  |
| variant_51 | may_issue_a_community_protection_notice | pass |  |
| variant_52 | may_issue_a_community_protection_notice | pass |  |
| variant_53 | may_issue_a_community_protection_notice | pass |  |
| variant_54 | may_issue_a_community_protection_notice | pass |  |
| variant_55 | may_issue_a_community_protection_notice | pass |  |
| variant_56 | may_issue_a_community_protection_notice | pass |  |
| variant_57 | may_issue_a_community_protection_notice | pass |  |
| variant_58 | may_issue_a_community_protection_notice | pass |  |
| variant_59 | may_issue_a_community_protection_notice | pass |  |
| variant_60 | may_issue_a_community_protection_notice | pass |  |
| variant_61 | may_issue_a_community_protection_notice | pass |  |
| variant_62 | may_issue_a_community_protection_notice | pass |  |
| variant_63 | may_issue_a_community_protection_notice | pass |  |
| variant_64 | may_issue_a_community_protection_notice | pass |  |
| variant_65 | may_issue_a_community_protection_notice | pass |  |
| variant_66 | may_issue_a_community_protection_notice | pass |  |
| variant_67 | may_issue_a_community_protection_notice | pass |  |
| variant_68 | may_issue_a_community_protection_notice | pass |  |
| variant_69 | may_issue_a_community_protection_notice | pass |  |
| variant_70 | may_issue_a_community_protection_notice | pass |  |
| variant_71 | may_issue_a_community_protection_notice | pass |  |
| variant_72 | may_issue_a_community_protection_notice | pass |  |
| variant_73 | may_issue_a_community_protection_notice | pass |  |
| variant_74 | may_issue_a_community_protection_notice | pass |  |
| variant_75 | may_issue_a_community_protection_notice | pass |  |
| variant_76 | may_issue_a_community_protection_notice | pass |  |
| variant_77 | may_issue_a_community_protection_notice | pass |  |
| variant_78 | may_issue_a_community_protection_notice | pass |  |
| variant_79 | may_issue_a_community_protection_notice | pass |  |
| variant_80 | may_issue_a_community_protection_notice | pass |  |
| variant_81 | may_issue_a_community_protection_notice | pass |  |
| variant_82 | may_issue_a_community_protection_notice | pass |  |
| variant_83 | may_issue_a_community_protection_notice | pass |  |
| variant_84 | may_issue_a_community_protection_notice | pass |  |
| variant_85 | may_issue_a_community_protection_notice | pass |  |
| variant_86 | may_issue_a_community_protection_notice | pass |  |
| variant_87 | may_issue_a_community_protection_notice | pass |  |
| variant_88 | may_issue_a_community_protection_notice | pass |  |
| variant_89 | may_issue_a_community_protection_notice | pass |  |
| variant_90 | may_issue_a_community_protection_notice | pass |  |
| variant_91 | may_issue_a_community_protection_notice | pass |  |
| variant_92 | may_issue_a_community_protection_notice | pass |  |
| variant_93 | may_issue_a_community_protection_notice | pass |  |
| variant_94 | may_issue_a_community_protection_notice | pass |  |
| variant_95 | may_issue_a_community_protection_notice | pass |  |
| variant_96 | may_issue_a_community_protection_notice | pass |  |
| variant_97 | may_issue_a_community_protection_notice | pass |  |
| variant_98 | may_issue_a_community_protection_notice | pass |  |
| variant_99 | may_issue_a_community_protection_notice | pass |  |
| variant_100 | may_issue_a_community_protection_notice | pass |  |
| variant_101 | may_issue_a_community_protection_notice | pass |  |
| variant_102 | may_issue_a_community_protection_notice | pass |  |
| variant_103 | may_issue_a_community_protection_notice | pass |  |
| variant_104 | may_issue_a_community_protection_notice | pass |  |
| variant_105 | may_issue_a_community_protection_notice | pass |  |
| variant_106 | may_issue_a_community_protection_notice | pass |  |
| variant_107 | may_issue_a_community_protection_notice | pass |  |
| variant_108 | may_issue_a_community_protection_notice | pass |  |
| variant_109 | may_issue_a_community_protection_notice | pass |  |
| variant_110 | may_issue_a_community_protection_notice | pass |  |
| variant_111 | may_issue_a_community_protection_notice | pass |  |
| variant_112 | may_issue_a_community_protection_notice | pass |  |
| variant_113 | may_issue_a_community_protection_notice | pass |  |
| variant_114 | may_issue_a_community_protection_notice | pass |  |
| variant_115 | may_issue_a_community_protection_notice | pass |  |
| variant_116 | may_issue_a_community_protection_notice | pass |  |
| variant_117 | may_issue_a_community_protection_notice | pass |  |
| variant_118 | may_issue_a_community_protection_notice | pass |  |
| variant_119 | may_issue_a_community_protection_notice | pass |  |
| variant_120 | may_issue_a_community_protection_notice | pass |  |
| variant_121 | may_issue_a_community_protection_notice | pass |  |
| variant_122 | may_issue_a_community_protection_notice | pass |  |
| variant_123 | may_issue_a_community_protection_notice | pass |  |
| variant_124 | may_issue_a_community_protection_notice | pass |  |
| variant_125 | may_issue_a_community_protection_notice | pass |  |
| variant_126 | may_issue_a_community_protection_notice | pass |  |
| variant_127 | may_issue_a_community_protection_notice | pass |  |
| variant_128 | may_issue_a_community_protection_notice | pass |  |

