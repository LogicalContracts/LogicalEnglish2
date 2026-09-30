# Migration ledger: imaginary_alcohol_act

Source: an L4 program (smucclaw/l4-ide) — imaginary-alcohol-act.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 17 |
| approximated | 0 |
| residue | 0 |
| **total** | 17 |

Fidelity: **152 of 152** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| the person is a body corporate | assume | encoded | a template the scenarios state (; undefined) | the person is a body corporate |  |
| the person engages in business for profit | assume | encoded | a template the scenarios state (; undefined) | the person engages in business for profit |  |
| the person is a public house | assume | encoded | a template the scenarios state (; undefined) | the person is a public house |  |
| the person is a hotel | assume | encoded | a template the scenarios state (; undefined) | the person is a hotel |  |
| the person has an unspent conviction for fraud | assume | encoded | a template the scenarios state (; undefined) | the person has an unspent conviction for fraud |  |
| the person has an unspent conviction for providing misleading information in relation to an application for a licence under an enactment | assume | encoded | a template the scenarios state (; undefined) | the person has an unspent conviction for providing misleading information in relation to an application for a licence under an enactment |  |
| the person has an alcohol banning order | assume | encoded | a template the scenarios state (; undefined) | the person has an alcohol banning order |  |
| the person must not sell alcohol | definition | encoded | pred | the person must not sell alcohol |  |
| a price list for alcohol is displayed on the premises | assume | encoded | a template the scenarios state (; undefined) | a price list for alcohol is displayed on the premises |  |
| the premises are registered as a hotel | assume | encoded | a template the scenarios state (; undefined) | the premises are registered as a hotel |  |
| the enforcement officer believes that the price list is misleading to customers | assume | encoded | a template the scenarios state (; undefined) | the enforcement officer believes that the price list is misleading to customers |  |
| the enforcement officer may issue a warning to the proprietor of premises | definition | encoded | pred | the enforcement officer may issue a warning to the proprietor of premises |  |
| the enforcement officer has issued a warning to the proprietor of premises | assume | encoded | a template the scenarios state (; undefined) | the enforcement officer has issued a warning to the proprietor of premises |  |
| the proprietor corrects the price list | assume | encoded | a template the scenarios state (; undefined) | the proprietor corrects the price list |  |
| the proprietor does so to the satisfaction of the enforcement officer | assume | encoded | a template the scenarios state (; undefined) | the proprietor does so to the satisfaction of the enforcement officer |  |
| the proprietor does so within 5 days after the warning was issued | assume | encoded | a template the scenarios state (; undefined) | the proprietor does so within 5 days after the warning was issued |  |
| the enforcement officer may cancel the registration of the hotel | definition | encoded | pred | the enforcement officer may cancel the registration of the hotel |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| variant_1 | the_person_must_not_sell_alcohol | pass |  |
| variant_2 | the_person_must_not_sell_alcohol | pass |  |
| variant_3 | the_person_must_not_sell_alcohol | pass |  |
| variant_4 | the_person_must_not_sell_alcohol | pass |  |
| variant_5 | the_person_must_not_sell_alcohol | pass |  |
| variant_6 | the_person_must_not_sell_alcohol | pass |  |
| variant_7 | the_person_must_not_sell_alcohol | pass |  |
| variant_8 | the_person_must_not_sell_alcohol | pass |  |
| variant_9 | the_person_must_not_sell_alcohol | pass |  |
| variant_10 | the_person_must_not_sell_alcohol | pass |  |
| variant_11 | the_person_must_not_sell_alcohol | pass |  |
| variant_12 | the_person_must_not_sell_alcohol | pass |  |
| variant_13 | the_person_must_not_sell_alcohol | pass |  |
| variant_14 | the_person_must_not_sell_alcohol | pass |  |
| variant_15 | the_person_must_not_sell_alcohol | pass |  |
| variant_16 | the_person_must_not_sell_alcohol | pass |  |
| variant_17 | the_person_must_not_sell_alcohol | pass |  |
| variant_18 | the_person_must_not_sell_alcohol | pass |  |
| variant_19 | the_person_must_not_sell_alcohol | pass |  |
| variant_20 | the_person_must_not_sell_alcohol | pass |  |
| variant_21 | the_person_must_not_sell_alcohol | pass |  |
| variant_22 | the_person_must_not_sell_alcohol | pass |  |
| variant_23 | the_person_must_not_sell_alcohol | pass |  |
| variant_24 | the_person_must_not_sell_alcohol | pass |  |
| variant_25 | the_person_must_not_sell_alcohol | pass |  |
| variant_26 | the_person_must_not_sell_alcohol | pass |  |
| variant_27 | the_person_must_not_sell_alcohol | pass |  |
| variant_28 | the_person_must_not_sell_alcohol | pass |  |
| variant_29 | the_person_must_not_sell_alcohol | pass |  |
| variant_30 | the_person_must_not_sell_alcohol | pass |  |
| variant_31 | the_person_must_not_sell_alcohol | pass |  |
| variant_32 | the_person_must_not_sell_alcohol | pass |  |
| variant_33 | the_person_must_not_sell_alcohol | pass |  |
| variant_34 | the_person_must_not_sell_alcohol | pass |  |
| variant_35 | the_person_must_not_sell_alcohol | pass |  |
| variant_36 | the_person_must_not_sell_alcohol | pass |  |
| variant_37 | the_person_must_not_sell_alcohol | pass |  |
| variant_38 | the_person_must_not_sell_alcohol | pass |  |
| variant_39 | the_person_must_not_sell_alcohol | pass |  |
| variant_40 | the_person_must_not_sell_alcohol | pass |  |
| variant_41 | the_person_must_not_sell_alcohol | pass |  |
| variant_42 | the_person_must_not_sell_alcohol | pass |  |
| variant_43 | the_person_must_not_sell_alcohol | pass |  |
| variant_44 | the_person_must_not_sell_alcohol | pass |  |
| variant_45 | the_person_must_not_sell_alcohol | pass |  |
| variant_46 | the_person_must_not_sell_alcohol | pass |  |
| variant_47 | the_person_must_not_sell_alcohol | pass |  |
| variant_48 | the_person_must_not_sell_alcohol | pass |  |
| variant_49 | the_person_must_not_sell_alcohol | pass |  |
| variant_50 | the_person_must_not_sell_alcohol | pass |  |
| variant_51 | the_person_must_not_sell_alcohol | pass |  |
| variant_52 | the_person_must_not_sell_alcohol | pass |  |
| variant_53 | the_person_must_not_sell_alcohol | pass |  |
| variant_54 | the_person_must_not_sell_alcohol | pass |  |
| variant_55 | the_person_must_not_sell_alcohol | pass |  |
| variant_56 | the_person_must_not_sell_alcohol | pass |  |
| variant_57 | the_person_must_not_sell_alcohol | pass |  |
| variant_58 | the_person_must_not_sell_alcohol | pass |  |
| variant_59 | the_person_must_not_sell_alcohol | pass |  |
| variant_60 | the_person_must_not_sell_alcohol | pass |  |
| variant_61 | the_person_must_not_sell_alcohol | pass |  |
| variant_62 | the_person_must_not_sell_alcohol | pass |  |
| variant_63 | the_person_must_not_sell_alcohol | pass |  |
| variant_64 | the_person_must_not_sell_alcohol | pass |  |
| variant_65 | the_person_must_not_sell_alcohol | pass |  |
| variant_66 | the_person_must_not_sell_alcohol | pass |  |
| variant_67 | the_person_must_not_sell_alcohol | pass |  |
| variant_68 | the_person_must_not_sell_alcohol | pass |  |
| variant_69 | the_person_must_not_sell_alcohol | pass |  |
| variant_70 | the_person_must_not_sell_alcohol | pass |  |
| variant_71 | the_person_must_not_sell_alcohol | pass |  |
| variant_72 | the_person_must_not_sell_alcohol | pass |  |
| variant_73 | the_person_must_not_sell_alcohol | pass |  |
| variant_74 | the_person_must_not_sell_alcohol | pass |  |
| variant_75 | the_person_must_not_sell_alcohol | pass |  |
| variant_76 | the_person_must_not_sell_alcohol | pass |  |
| variant_77 | the_person_must_not_sell_alcohol | pass |  |
| variant_78 | the_person_must_not_sell_alcohol | pass |  |
| variant_79 | the_person_must_not_sell_alcohol | pass |  |
| variant_80 | the_person_must_not_sell_alcohol | pass |  |
| variant_81 | the_person_must_not_sell_alcohol | pass |  |
| variant_82 | the_person_must_not_sell_alcohol | pass |  |
| variant_83 | the_person_must_not_sell_alcohol | pass |  |
| variant_84 | the_person_must_not_sell_alcohol | pass |  |
| variant_85 | the_person_must_not_sell_alcohol | pass |  |
| variant_86 | the_person_must_not_sell_alcohol | pass |  |
| variant_87 | the_person_must_not_sell_alcohol | pass |  |
| variant_88 | the_person_must_not_sell_alcohol | pass |  |
| variant_89 | the_person_must_not_sell_alcohol | pass |  |
| variant_90 | the_person_must_not_sell_alcohol | pass |  |
| variant_91 | the_person_must_not_sell_alcohol | pass |  |
| variant_92 | the_person_must_not_sell_alcohol | pass |  |
| variant_93 | the_person_must_not_sell_alcohol | pass |  |
| variant_94 | the_person_must_not_sell_alcohol | pass |  |
| variant_95 | the_person_must_not_sell_alcohol | pass |  |
| variant_96 | the_person_must_not_sell_alcohol | pass |  |
| variant_97 | the_person_must_not_sell_alcohol | pass |  |
| variant_98 | the_person_must_not_sell_alcohol | pass |  |
| variant_99 | the_person_must_not_sell_alcohol | pass |  |
| variant_100 | the_person_must_not_sell_alcohol | pass |  |
| variant_101 | the_person_must_not_sell_alcohol | pass |  |
| variant_102 | the_person_must_not_sell_alcohol | pass |  |
| variant_103 | the_person_must_not_sell_alcohol | pass |  |
| variant_104 | the_person_must_not_sell_alcohol | pass |  |
| variant_105 | the_person_must_not_sell_alcohol | pass |  |
| variant_106 | the_person_must_not_sell_alcohol | pass |  |
| variant_107 | the_person_must_not_sell_alcohol | pass |  |
| variant_108 | the_person_must_not_sell_alcohol | pass |  |
| variant_109 | the_person_must_not_sell_alcohol | pass |  |
| variant_110 | the_person_must_not_sell_alcohol | pass |  |
| variant_111 | the_person_must_not_sell_alcohol | pass |  |
| variant_112 | the_person_must_not_sell_alcohol | pass |  |
| variant_113 | the_person_must_not_sell_alcohol | pass |  |
| variant_114 | the_person_must_not_sell_alcohol | pass |  |
| variant_115 | the_person_must_not_sell_alcohol | pass |  |
| variant_116 | the_person_must_not_sell_alcohol | pass |  |
| variant_117 | the_person_must_not_sell_alcohol | pass |  |
| variant_118 | the_person_must_not_sell_alcohol | pass |  |
| variant_119 | the_person_must_not_sell_alcohol | pass |  |
| variant_120 | the_person_must_not_sell_alcohol | pass |  |
| variant_121 | the_person_must_not_sell_alcohol | pass |  |
| variant_122 | the_person_must_not_sell_alcohol | pass |  |
| variant_123 | the_person_must_not_sell_alcohol | pass |  |
| variant_124 | the_person_must_not_sell_alcohol | pass |  |
| variant_125 | the_person_must_not_sell_alcohol | pass |  |
| variant_126 | the_person_must_not_sell_alcohol | pass |  |
| variant_127 | the_person_must_not_sell_alcohol | pass |  |
| variant_128 | the_person_must_not_sell_alcohol | pass |  |
| variant_129 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_130 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_131 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_132 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_133 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_134 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_135 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_136 | the_enforcement_officer_may_issue_a_warning_to_the_proprietor_of_premises | pass |  |
| variant_137 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_138 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_139 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_140 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_141 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_142 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_143 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_144 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_145 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_146 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_147 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_148 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_149 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_150 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_151 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |
| variant_152 | the_enforcement_officer_may_cancel_the_registration_of_the_hotel | pass |  |

