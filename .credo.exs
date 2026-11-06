# This file contains the configuration for Credo and you are probably reading
# this after creating it with `mix credo.gen.config`.
#
# If you find anything wrong or unclear in this file, please report an
# issue on GitHub: https://github.com/rrrene/credo/issues
#
%{
  #
  # You can have as many configs as you like in the `configs:` field.
  configs: [
    %{
      #
      # Run any config using `mix credo -C <name>`. If no config name is given
      # "default" is used.
      #
      name: "default",
      #
      # These are the files included in the analysis:
      files: %{
        #
        # You can give explicit globs or simply directories.
        # In the latter case `**/*.{ex,exs}` will be used.
        #
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      #
      # Load and configure plugins here:
      # ExSlop adds ~30 high-signal checks for AI-generated code patterns.
      # ExDNA detects duplicate/cloned code across the codebase.
      # Bylaw.Credo.Plugin.DisableForNextDefinition adds
      #   `# credo:disable-for-next-definition <Check>`, which scopes a suppression to a
      #   whole function clause instead of one line. Works for every suite here.
      # Bylaw.Credo.Plugin.HEExSources is deliberately NOT enabled: it feeds standalone
      #   `.html.heex` files to every check, and the plain-Elixir ones (e.g.
      #   Consistency.SpaceAroundOperators) then report ~90 false positives on markup.
      #   Credo already parses `~H` sigils inside `.ex` files, which is where all but
      #   four of this app's templates live.
      # Llamex ships as a plugin too, but an explicit `checks.enabled` list is
      #   authoritative in Credo and discards plugin-injected checks, so its checks are
      #   listed below by hand instead.
      #
      plugins: [
        {ExSlop, []},
        {ExDNA.Credo, []},
        {Bylaw.Credo.Plugin.DisableForNextDefinition, []}
      ],
      #
      # If you create your own checks, you must specify the source files for
      # them here, so they can be loaded by Credo before running the analysis.
      #
      requires: [],
      #
      # If you want to enforce a style guide and need a more traditional linting
      # experience, you can change `strict` to `true` below:
      #
      strict: false,
      #
      # To modify the timeout for parsing files, change this value:
      #
      parse_timeout: 5000,
      #
      # If you want to use uncolored output by default, you can change `color`
      # to `false` below:
      #
      color: true,
      #
      # You can customize the parameters of any check by adding a second element
      # to the tuple.
      #
      # To disable a check put `false` as second element:
      #
      #     {Credo.Check.Design.DuplicatedCode, false}
      #
      checks: %{
        enabled: [
          #
          ## Consistency Checks
          #
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          #
          ## Design Checks
          #
          # You can customize the priority of any check
          # Priority values are: `low, normal, high, higher`
          #
          {Credo.Check.Design.AliasUsage,
           [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagFIXME, []},
          # TODOs are tracked in tasks/ files; Credo just surfaces them, doesn't fail CI.
          {Credo.Check.Design.TagTODO, [exit_status: 0]},

          #
          ## Readability Checks
          #
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          #
          ## Refactoring Opportunities
          #
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},

          #
          ## Warnings
          #
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.StructFieldAmount, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedMapOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFilename, []},

          #
          ## Extra strict checks enabled for this project
          #
          {Credo.Check.Refactor.UtcNowTruncate, []},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.UnsafeToAtom, []},

          #
          ## ExSlop README's recommended built-in checks for AI-slop catching
          #
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},

          #
          ## ExSlop plugin checks
          #
          {ExSlop.Check.Warning.BlanketRescue, []},
          {ExSlop.Check.Warning.RescueWithoutReraise, []},
          {ExSlop.Check.Warning.RepoAllThenFilter, []},
          {ExSlop.Check.Warning.QueryInEnumMap, []},
          {ExSlop.Check.Warning.GenserverAsKvStore, []},
          {ExSlop.Check.Warning.PathExpandPriv, []},
          {ExSlop.Check.Warning.DualKeyAccess, []},
          {ExSlop.Check.Refactor.FilterNil, []},
          {ExSlop.Check.Refactor.RejectNil, []},
          {ExSlop.Check.Refactor.ReduceAsMap, []},
          {ExSlop.Check.Refactor.MapIntoLiteral, []},
          {ExSlop.Check.Refactor.IdentityPassthrough, []},
          {ExSlop.Check.Refactor.IdentityMap, []},
          {ExSlop.Check.Refactor.CaseTrueFalse, []},
          {ExSlop.Check.Refactor.TryRescueWithSafeAlternative, []},
          {ExSlop.Check.Refactor.WithIdentityElse, []},
          {ExSlop.Check.Refactor.WithIdentityDo, []},
          {ExSlop.Check.Refactor.SortThenReverse, []},
          {ExSlop.Check.Refactor.StringConcatInReduce, []},
          {ExSlop.Check.Refactor.ReduceMapPut, []},
          {ExSlop.Check.Refactor.RedundantBooleanIf, []},
          {ExSlop.Check.Refactor.FlatMapFilter, []},
          {ExSlop.Check.Readability.NarratorDoc, []},
          {ExSlop.Check.Readability.BoilerplateDocParams, []},
          {ExSlop.Check.Readability.NarratorComment, []},
          {ExSlop.Check.Readability.ObviousComment, []},
          {ExSlop.Check.Readability.StepComment, []},
          {ExSlop.Check.Readability.DocFalseOnPublicFunction, []},
          {ExSlop.Check.Readability.UnaliasedModuleUse, []},
          {ExSlop.Check.Refactor.RedundantEnumJoinSeparator, []},
          {ExSlop.Check.Refactor.GraphemesLength, []},
          {ExSlop.Check.Refactor.ManualStringReverse, []},
          {ExSlop.Check.Refactor.SortThenAt, []},
          {ExSlop.Check.Refactor.SortForTopK, []},
          {ExSlop.Check.Refactor.ExplicitSumReduce, []},

          #
          ## ExDNA clone detection
          #
          {ExDNA.Credo, [min_mass: 40]},

          #
          ## bylaw_credo + llamex
          #
          # Measured against the whole tree before enabling (see the `credo-checks`
          # skill for how to re-measure). Inherited from Exhs, plus fourteen more
          # enabled on the fresh scaffold.
          #
          {Bylaw.Credo.Check.Ecto.ComposablePreloadQueries, []},
          {Bylaw.Credo.Check.Ecto.ErrorChangesetPatternMatch, []},
          {Bylaw.Credo.Check.Ecto.NamedBinding, []},
          {Bylaw.Credo.Check.Ecto.NoAndInWhere, []},
          {Bylaw.Credo.Check.Ecto.NoDataChangesInSchemaMigrations, []},
          {Bylaw.Credo.Check.Ecto.NoRepoPreloadAfterQuery, []},
          {Bylaw.Credo.Check.Ecto.NoRepoTransaction, []},
          {Bylaw.Credo.Check.Ecto.OwnContextForSchema, []},
          {Bylaw.Credo.Check.Ecto.PipeBasedQueries, []},
          {Bylaw.Credo.Check.Ecto.PreferDateTimeOverDate, []},
          {Bylaw.Credo.Check.Ecto.PreferOrderByOverRepoAllEnumSort, []},
          {Bylaw.Credo.Check.Ecto.PreferRepoAggregateCount, []},
          {Bylaw.Credo.Check.Ecto.PreferRepoOneOverAllFirst, []},
          {Bylaw.Credo.Check.Ecto.PreferSelectOverRepoAllEnumMap, []},
          {Bylaw.Credo.Check.Ecto.UseMyAppSchema, []},
          {Bylaw.Credo.Check.Elixir.AppModuleAcronymCasing, []},
          {Bylaw.Credo.Check.Elixir.DocBeforeSpec, []},
          {Bylaw.Credo.Check.Elixir.FilterRejectFirst, []},
          {Bylaw.Credo.Check.Elixir.FloatUsage, []},
          {Bylaw.Credo.Check.Elixir.FullySpecifiedStructTypes, []},
          {Bylaw.Credo.Check.Elixir.FullyTypedOpts, []},
          {Bylaw.Credo.Check.Elixir.NoEndOfDayTime, []},
          {Bylaw.Credo.Check.Elixir.NoExtraPublicBehaviourFunctions, []},
          {Bylaw.Credo.Check.Elixir.NoPassthroughWrapper, []},
          {Bylaw.Credo.Check.Elixir.NoRemoteCallsInModuleAttributes, []},
          {Bylaw.Credo.Check.Elixir.NoResultTupleArgument, []},
          {Bylaw.Credo.Check.Elixir.NoThen, []},
          {Bylaw.Credo.Check.Elixir.NoTryRescue, []},
          {Bylaw.Credo.Check.Elixir.PreferEnumUniqBy, []},
          {Bylaw.Credo.Check.Elixir.PreferListTypeSyntax, []},
          {Bylaw.Credo.Check.Elixir.RejectCount, []},
          {Bylaw.Credo.Check.Elixir.UseMaybeInFunctionName, []},
          {Bylaw.Credo.Check.HEEx.DesignSystem.NoArbitrarySpacing, []},
          {Bylaw.Credo.Check.HEEx.NoDuplicateStaticIds, []},
          {Bylaw.Credo.Check.HEEx.NoJavascriptHref, []},
          {Bylaw.Credo.Check.HEEx.PreferLinkForNavigation, []},
          {Bylaw.Credo.Check.HEEx.PreferNativeInteractiveElement, []},
          {Bylaw.Credo.Check.HEEx.RequireAccessibleButtonText, []},
          {Bylaw.Credo.Check.HEEx.RequireImageAlt, []},
          {Bylaw.Credo.Check.HEEx.RequireLinkHref, []},
          {Bylaw.Credo.Check.HEEx.RequireLinkText, []},
          {Bylaw.Credo.Check.HEEx.RequireTargetBlankRel, []},
          {Bylaw.Credo.Check.Phoenix.ContextFunctionNaming, []},
          {Bylaw.Credo.Check.Phoenix.NoRepoInController, []},
          {Bylaw.Credo.Check.Phoenix.URIDecodeQuery, []},
          {Bylaw.Credo.Check.Phoenix.UseVerifiedRoutes, []},
          {Bylaw.Credo.Check.Testing.PreferSelectorAssertionsForHtml, []},
          {Llamex.Check.NoDBWorkInMemory, []},
          {Llamex.Check.NoOneLiners, []},
          {Llamex.Check.NoSelfInLiveViews, []},
          {Llamex.Check.NoAuthorizeBypass, []},
          {Llamex.Check.NoMultipleAssigns, []},
          {Bylaw.Credo.Check.Elixir.NoLowLevelProcessPrimitives, []},
          {Bylaw.Credo.Check.Elixir.NoCatchAllInWithElse, []},
          {Bylaw.Credo.Check.HEEx.RequireLabelForInput, []},
          {Bylaw.Credo.Check.HEEx.NoIndirectAssignAccess, []},
          {Bylaw.Credo.Check.HEEx.RequireButtonType, []},
          {Bylaw.Credo.Check.HEEx.RequireLoadingStateForSubmit, []},
          {Bylaw.Credo.Check.PhoenixLiveView.NoInlineAssignInReturnTuple, []},
          {Llamex.Check.NoAdHocAshQueries, []},
          {Bylaw.Credo.Check.Elixir.PreferEmptyListChecks, []},
          {Bylaw.Credo.Check.PhoenixLiveView.RequireFunctionComponentAttrs, []},
          {Bylaw.Credo.Check.Elixir.WithElseClause, []},
          {Bylaw.Credo.Check.Elixir.PreferEnumCount, []}
          #
          # Parked, with the violation count measured on the tree at the time
          # (2026-11-06, initial scaffold). Work them down and move them up; do not
          # enable one without fixing its findings. SafeDateTimeComparison flags `<`
          # inside Ash `expr/1` (generated Token resource) — a false positive there.
          # NoGlobalStateInTests flags the slot test, which must set env vars.
          #
          # NoRaise and the Testing.* checks conflict with conventions this project has
          # chosen on purpose (bang functions; `describe`/`setup` blocks per the
          # `testing` skill), so they are unlikely ever to move.
          #
          # {Bylaw.Credo.Check.Elixir.NoRaise, []},  # 64
          # {Bylaw.Credo.Check.HEEx.NoElementSpacing, []},  # 8
          # {Llamex.Check.NoLLMismsInComments, []},  # 12
          # {Bylaw.Credo.Check.Elixir.NoParamExtractionInFunctionHead, []},  # 7
          # {Llamex.Check.ConsistentInterfaces, []},  # 6
          # {Bylaw.Credo.Check.Testing.NoSetupInTests, []},  # 2
          # {Bylaw.Credo.Check.Testing.NoTestsInTestDir, []},  # 6
          # {Bylaw.Credo.Check.Elixir.PreferBlockIf, []},  # 7
          # {Bylaw.Credo.Check.Testing.NoDescribeBlocks, []},  # 10
          # {Bylaw.Credo.Check.Elixir.SafeDateTimeComparison, []},  # 2
          # {Bylaw.Credo.Check.Testing.NoGlobalStateInTests, []},  # 4
          # {Bylaw.Credo.Check.Elixir.NamedSpecParams, []},  # 15
          #
          # Bylaw.Credo.Check.Ecto.ContextOwnsSchemaQueries and
          # Bylaw.Credo.Check.Elixir.SimpleTaggedTupleValues crash on this tree
          # (FunctionClauseError in the check itself, bylaw_credo 0.4.0). Left out.
          #
        ],
        disabled: [
          #
          # Controversial and experimental checks (opt-in, just move the check to `:enabled`
          #   and be sure to use `mix credo --strict` to see low priority checks)
          #
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.UnusedVariableNames, []},
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Design.SkipTestWithoutComment, []},
          {Credo.Check.Readability.AliasAs, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, []},
          {Credo.Check.Readability.OneArityFunctionInPipe, []},
          {Credo.Check.Readability.OnePipePerLine, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, []},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},
          {Credo.Check.Refactor.ABCSize, []},
          {Credo.Check.Refactor.CondInsteadOfIfElse, []},
          {Credo.Check.Refactor.ModuleDependencies, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.VariableRebinding, []}
          # {Credo.Check.Warning.UnusedOperation, [{MyMagicModule, [:fun1, :fun2]}]}

          # {Credo.Check.Refactor.MapInto, []},

          #
          # Custom checks can be created using `mix credo.gen.check`.
          #
        ]
      }
    }
  ]
}
