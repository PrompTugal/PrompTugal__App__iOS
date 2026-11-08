import PTAgenda
import PTNews

// The news screens (PTNews) read the feed's stories through NewsSource. PTAgenda must not import PTNews,
// so each app declares the conformance itself (the Team app has its own copy).
extension ReaderStore: NewsSource {}
