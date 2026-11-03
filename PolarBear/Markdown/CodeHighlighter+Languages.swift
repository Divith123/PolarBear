//
//  CodeHighlighter+Languages.swift
//  PolarBear
//

import Foundation

/// The keyword lists of the languages `CodeHighlighter` knows.
nonisolated extension CodeHighlighter.Rules {
    private static func words(_ text: String) -> Set<String> {
        Set(text.split(whereSeparator: \.isWhitespace).map(String.init))
    }

    static let swift = CodeHighlighter.Rules(
        keywords: words("""
        actor any as associatedtype async await break case catch class continue default defer deinit do else enum \
        extension fallthrough fileprivate final for func guard if import in indirect init inout internal is let \
        mutating nonisolated nonmutating open operator override private protocol public repeat rethrows return \
        self Self some static struct subscript super switch throw throws try typealias var where while \
        @MainActor @Observable @State @Binding @Environment
        """),
        constants: words("true false nil"),
        multilineQuotes: [],
        tripleQuotes: true,
        atWordIsAttribute: true,
        hashWordIsDirective: true
    )

    static let rust = CodeHighlighter.Rules(
        keywords: words("""
        as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move \
        mut pub ref return self Self static struct super trait type unsafe use where while macro_rules
        """),
        constants: words("true false None Some Ok Err"),
        multilineQuotes: [],
        hashWordIsDirective: true
    )

    static let javascript = CodeHighlighter.Rules(
        keywords: words("""
        async await break case catch class const continue debugger default delete do else export extends finally \
        for from function if import in instanceof let new of return static super switch this throw try typeof \
        var void while with yield get set
        """),
        constants: words("true false null undefined NaN Infinity"),
        stringQuotes: ["\"", "'"],
        multilineQuotes: ["`"]
    )

    static let typescript = CodeHighlighter.Rules(
        keywords: javascript.keywords.union(words("""
        abstract as declare enum implements interface keyof module namespace never private protected public \
        readonly type unknown any string number boolean symbol object is infer satisfies
        """)),
        constants: javascript.constants,
        multilineQuotes: ["`"],
        atWordIsAttribute: true
    )

    static let python = CodeHighlighter.Rules(
        keywords: words("""
        and as assert async await break class continue def del elif else except finally for from global if import \
        in is lambda nonlocal not or pass raise return try while with yield match case self cls
        """),
        constants: words("True False None"),
        lineComments: ["#"],
        blockComment: nil,
        multilineQuotes: [],
        tripleQuotes: true,
        atWordIsAttribute: true
    )

    static let sql = CodeHighlighter.Rules(
        keywords: words("""
        select from where and or not null insert into values update set delete create table index drop alter add \
        primary key foreign references unique default join inner outer left right full on group by order having \
        limit offset as distinct union all case when then else end in is like ilike between exists asc desc with \
        view trigger begin commit rollback constraint check cascade varchar text integer int bigint uuid boolean \
        timestamp date decimal numeric serial returning count sum avg min max coalesce current_timestamp
        """),
        lineComments: ["--"],
        stringQuotes: ["'"],
        multilineQuotes: [],
        isCaseInsensitive: true,
        capitalisedIsType: false
    )

    static let shell = CodeHighlighter.Rules(
        keywords: words("""
        if then else elif fi for while until do done case esac in function select time return exit break continue \
        local export readonly declare unset source alias echo cd set shift trap eval exec printf read test
        """),
        lineComments: ["#"],
        blockComment: nil,
        multilineQuotes: [],
        capitalisedIsType: false,
        variablePrefix: "$"
    )

    static let cLike = CodeHighlighter.Rules(
        keywords: words("""
        auto break case char class const constexpr continue default delete do double else enum explicit extern \
        float for friend goto if inline int long mutable namespace new noexcept nullptr operator override private \
        protected public register return short signed sizeof static struct switch template this throw try typedef \
        typename union unsigned using virtual void volatile while bool abstract as async await base checked event \
        foreach get in interface internal is lock out params partial readonly ref sealed set string value var yield
        """),
        constants: words("true false NULL null nullptr"),
        multilineQuotes: [],
        hashWordIsDirective: true
    )

    static let java = CodeHighlighter.Rules(
        keywords: words("""
        abstract assert boolean break byte case catch char class const continue default do double else enum \
        extends final finally float for goto if implements import instanceof int interface long native new package \
        private protected public return short static strictfp super switch synchronized this throw throws transient \
        try void volatile while fun val var when object companion data sealed override open lateinit suspend \
        inline internal is in out by init typealias trait def lazy match implicit
        """),
        constants: words("true false null"),
        multilineQuotes: [],
        tripleQuotes: true,
        atWordIsAttribute: true
    )

    static let go = CodeHighlighter.Rules(
        keywords: words("""
        break case chan const continue default defer else fallthrough for func go goto if import interface map \
        package range return select struct switch type var
        """),
        constants: words("true false nil iota"),
        stringQuotes: ["\"", "'"],
        multilineQuotes: ["`"]
    )

    static let ruby = CodeHighlighter.Rules(
        keywords: words("""
        alias and begin break case class def defined do else elsif end ensure for if in module next not or redo \
        rescue retry return self super then undef unless until when while yield require include extend attr_reader \
        attr_writer attr_accessor puts
        """),
        constants: words("true false nil"),
        lineComments: ["#"],
        blockComment: nil,
        multilineQuotes: []
    )

    static let php = CodeHighlighter.Rules(
        keywords: words("""
        abstract and array as break case catch class clone const continue declare default do echo else elseif \
        empty extends final finally fn for foreach function global if implements include interface isset list \
        namespace new or print private protected public require return static switch throw trait try unset use \
        var while yield
        """),
        constants: words("true false null"),
        lineComments: ["//", "#"],
        multilineQuotes: [],
        variablePrefix: "$"
    )

    static let lua = CodeHighlighter.Rules(
        keywords: words("and break do else elseif end for function goto if in local not or repeat return then until while"),
        constants: words("true false nil"),
        lineComments: ["--"],
        blockComment: ("--[[", "]]"),
        multilineQuotes: [],
        capitalisedIsType: false
    )

    static let toml = CodeHighlighter.Rules(
        keywords: [],
        constants: words("true false"),
        lineComments: ["#", ";"],
        blockComment: nil,
        multilineQuotes: [],
        capitalisedIsType: false
    )

    static let tex = CodeHighlighter.Rules(
        keywords: [],
        lineComments: ["%"],
        blockComment: nil,
        stringQuotes: [],
        multilineQuotes: [],
        capitalisedIsType: false
    )

    static let json = CodeHighlighter.Rules(
        keywords: [],
        constants: words("true false null"),
        lineComments: ["//"],
        stringQuotes: ["\""],
        multilineQuotes: [],
        capitalisedIsType: false,
        highlightsKeys: true
    )
}
