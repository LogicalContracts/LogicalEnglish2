/** <module> Logical English Graph Generator
    
    This module generates a graph representation of a Logical English knowledge base,
    suitable for rendering with Cytoscape.js.
*/

:- module(le_graph, [kb_graph/2]).

:- use_module(le_kbs).
:- use_module(le_verifier).
:- use_module(le_system_templates).

:- discontiguous node/2.
:- discontiguous edge/3.

%!  kb_graph(+KBModule:atom, -Graph:dict) is det.
%
%   Generates a graph representation of the given KB module.
kb_graph(KB, _{nodes: Nodes, edges: Edges}) :-
    collect_nodes(KB, Nodes),
    collect_edges(KB, Nodes, Edges).

%!  collect_nodes(+KBModule:atom, -Nodes:list) is det.
collect_nodes(KB, Nodes) :-
    findall(Node, node(KB, Node), Nodes).

% Template Nodes
node(KB, _{data: _{id: TID, type: "template", label: Label, functor: F, arity: Arity,
                   source: _{start: Start, end: End}}}) :-
    current_predicate(KB:le_dict/1),
    KB:le_dict(dict(FA, NTs, WV)),
    \+ le_system_templates:le_system_template(dict(FA, NTs, WV)),
    FA = [F|Args],
    length(Args, Arity),
    format(atom(TID), 'template_~w_~w', [F, Arity]),
    copy_term(NTs-WV, NTsC-WVC),
    maplist(fill_type_with_stars, NTsC),
    le_kbs:canonical_string(WVC, Label),
    ( KB:le_source_info(Ref, Start, End, template), catch(clause(KB:le_dict(dict(FA, NTs, WV)), true, Ref), _, fail) -> true ; Start = 0, End = 0).

% Rule, Fact, Scenario, and Query Nodes
node(KB, _{data: Data}) :-
    KB:le_source_info(Ref, Start, End, RID),
    \+ member(RID, [template, ontology, session_fact, none]),
    ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true ),
    % Exclude system facts
    \+ (Body == true, (Head = le_kb(_) ; Head = le_expected(_,_,_))),
    ( Head = scenario(SName, _) -> 
        format(atom(SID), 'scenario_~w', [SName]),
        Data = _{id: SID, type: "scenario", label: SName, source: _{start: Start, end: End}}
    ; Head = query_info(QName, _, _) ->
        format(atom(QID), 'query_~w', [QName]),
        Data = _{id: QID, type: "query", label: QName, source: _{start: Start, end: End}}
    ; Body == true -> 
        rule_label(KB, Head, Body, Label),
        Data = _{id: RID, type: "fact", label: Label, source: _{start: Start, end: End}}
    ; 
        rule_label(KB, Head, Body, Label),
        Data = _{id: RID, type: "rule", label: Label, source: _{start: Start, end: End}}
    ).

% Scenario Fact Nodes
node(KB, _{data: _{id: FID, type: "fact", label: Label, parent: SID,
                   source: _{start: Start, end: End}}}) :-
    current_predicate(KB:scenario/2),
    KB:scenario(SName, Terms),
    format(atom(SID), 'scenario_~w', [SName]),
    member(FactItem, Terms),
    ( FactItem = fact_with_source(Term, Start, End) -> true ; Term = FactItem, Start = 0, End = 0 ),
    rule_label(KB, Term, true, Label),
    format(atom(FID), 'fact_~w', [Start]).

% Scenario containment edges (to ensure Cytoscape sees the relationship)
edge(_KB, Nodes, _{data: _{id: EID, source: SID, target: FID, type: "scopes"}}) :-
    member(SNode, Nodes),
    get_dict(data, SNode, SData),
    get_dict(type, SData, "scenario"),
    get_dict(id, SData, SID),
    
    member(FNode, Nodes),
    get_dict(data, FNode, FData),
    get_dict(type, FData, "fact"),
    get_dict(parent, FData, SID),
    get_dict(id, FData, FID),
    
    atomic_list_concat([SID, '-contains-', FID], EID).

% Type Nodes
node(KB, _{data: _{id: TID, type: "type", label: Type,
                   source: _{start: Start, end: End}}}) :-
    catch(le_kbs:is_a_hierarchy(KB, Hierarchy), _, fail),
    flatten_hierarchy(Hierarchy, Flat),
    member(Node, Flat),
    Type = Node.type,
    (   Node.range \== null
    ->  Start = Node.range.start, End = Node.range.end
    ;   Start = 0, End = 0
    ),
    format(atom(TID), 'type_~w', [Type]).

flatten_hierarchy([], []).
flatten_hierarchy([Node|Rest], [Node|Flat]) :-
    flatten_hierarchy(Node.children, ChildrenFlat),
    flatten_hierarchy(Rest, RestFlat),
    append(ChildrenFlat, RestFlat, Flat).

% Edges
collect_edges(KB, Nodes, Edges) :-
    findall(Edge, edge(KB, Nodes, Edge), Edges).

edge(KB, Nodes, _{data: _{id: EID, source: RID, target: TID, type: Type}}) :-
    member(Node, Nodes),
    get_dict(data, Node, Data),
    get_dict(id, Data, RID),
    get_dict(type, Data, RType),
    (RType == "rule" ; RType == "fact" ; RType == "query"),
    ( RID = RID_Atom, atom(RID_Atom) -> true ; RID = RID_Atom ),

    ( atom_concat('query_', QName, RID_Atom) ->
        KB:le_source_info(Ref, _, _, QName),
        ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true )
    ; atom_concat('scenario_', SName, RID_Atom) ->
        KB:le_source_info(Ref, _, _, SName),
        ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true )
    ; atom_concat('fact_', OffsetAtom, RID_Atom) -> 
        atom_number(OffsetAtom, Offset),
        ( (current_predicate(KB:scenario/2), catch(KB:scenario(_SName, Terms), _, fail), member(FactItem, Terms), (FactItem = fact_with_source(Head, Start, _End) -> Start == Offset ; Head = FactItem, Offset == 0)) -> true ; Head = unknown ),
        Body = true
    ; KB:le_source_info(Ref, _, _, RID_Atom),
      ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true )
    ),
    ( Head = query_info(_, Goal, _) -> Body1 = Goal, Head1 = true ; Body1 = Body, Head1 = Head ),
    ( literal_uses_template(KB, Head1, TID, Nodes), Type = "uses"
    ; le_verifier:find_in_body(Body1, Literal),
      ( Literal = not(G) -> Type = "negates", G1 = G ; Type = "uses", G1 = Literal ),
      literal_uses_template(KB, G1, TID, Nodes)
    ),
    atomic_list_concat([RID, '-', TID, '-', Type], EID).

% ISA Edges (Hierarchy-based)
edge(KB, Nodes, _{data: _{id: EID, source: SubID, target: SuperID, type: "is-a"}}) :-
    catch(le_kbs:is_a_hierarchy(KB, Hierarchy), _, fail),
    flatten_hierarchy(Hierarchy, Flat),
    member(ParentNode, Flat),
    member(ChildNode, ParentNode.children),
    SubType = ChildNode.type,
    SuperType = ParentNode.type,
    
    member(SubNode, Nodes),
    get_dict(data, SubNode, SubData),
    get_dict(id, SubData, SubID),
    get_dict(label, SubData, SubType),
    
    member(SuperNode, Nodes),
    get_dict(data, SuperNode, SuperData),
    get_dict(id, SuperData, SuperID),
    get_dict(label, SuperData, SuperType),
    
    atomic_list_concat([SubID, '-isa-', SuperID], EID).

% Template defines Type Edges
edge(KB, Nodes, _{data: _{id: EID, source: TID, target: TypeID, type: "defines"}}) :-
    member(TNode, Nodes),
    get_dict(data, TNode, TData),
    get_dict(type, TData, "template"),
    get_dict(id, TData, TID),
    
    current_predicate(KB:le_dict/1),
    KB:le_dict(dict(FA, NTs, _)),
    FA = [F|Args],
    length(Args, Arity),
    get_dict(functor, TData, F),
    get_dict(arity, TData, Arity),
    
    member(V-Type, NTs),
    atom(Type),
    
    member(TypeNode, Nodes),
    get_dict(data, TypeNode, TypeData),
    get_dict(type, TypeData, "type"),
    get_dict(label, TypeData, Type),
    get_dict(id, TypeData, TypeID),
    
    ( var(V) -> VName = 'var' ; VName = V ),
    atomic_list_concat([TID, '-defines-', TypeID, '-', VName], EID).





literal_uses_template(_KB, Literal, TID, Nodes) :-
    ( Literal = not(G) -> (compound(G) -> G =.. [F|Args] ; F = G, Args = [])
    ; compound(Literal) -> Literal =.. [F|Args]
    ; F = Literal, Args = []
    ),
    length(Args, Arity),
    member(Node, Nodes),
    get_dict(data, Node, Data),
    get_dict(type, Data, "template"),
    get_dict(functor, Data, F),
    get_dict(arity, Data, Arity),
    get_dict(id, Data, TID).
% --- Helpers ---

fill_type_with_stars(V-Type) :-
    (   atom(Type) -> format(atom(V), "*~w*", [Type])
    ;   V = '*variable*'
    ).

rule_label(KB, Head, Body, Label) :-
    ( le_kbs:item_to_instance(KB, Head, HeadTokens) ->
        le_kbs:canonical_string(HeadTokens, HeadStr)
    ; term_string(Head, HeadStr)
    ),
    ( Body == true -> Label = HeadStr
    ; body_to_compact_le(KB, Body, BodyStr),
      format(string(Label), "~w\nif\n~w", [HeadStr, BodyStr])
    ).

body_to_compact_le(KB, Body, Str) :-
    findall(L, le_verifier:find_in_body(Body, L), Literals),
    ( Literals = [] -> Str = "..."
    ; maplist(literal_to_le(KB), Literals, LEs),
      atomic_list_concat(LEs, ',\n', FullBody),
      ( string_length(FullBody, Len), Len > 60 -> 
        sub_string(FullBody, 0, 60, _, Sub),
        string_concat(Sub, "...", Str)
      ; Str = FullBody
      )
    ).

literal_to_le(KB, L, Str) :-
    ( L = not(G) -> literal_to_le(KB, G, GStr), string_concat("not ", GStr, Str)
    ; le_kbs:item_to_instance(KB, L, Tokens) -> le_kbs:canonical_string(Tokens, Str)
    ; term_string(L, Str)
    ).
