import ArgumentParser

@main
struct SymbolReelCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "symbolreel",
        abstract: "Export SF Symbols animations as transparent video, MP4, GIF and PNG frames.",
        discussion: """
        Examples:
          symbolreel wifi -e variable-color.iterative
          symbolreel signature -e draw-on -f prores,mp4 --color "#FF9500"
          symbolreel bell.fill heart.fill -e bounce -e wiggle --repeat 3 -o exports
          symbolreel wifi -e replace.magic --to wifi.slash -f hevc-alpha
        """,
        version: "0.1.0",
        subcommands: [RenderCommand.self, EffectsCommand.self, FormatsCommand.self],
        defaultSubcommand: RenderCommand.self
    )
}
