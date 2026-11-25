--!strict

export type Page = "Play" | "Heroes" | "Store" | "Friends"
export type RoleSlot = "Primary" | "Secondary"
export type FriendStatus = "Online" | "InGame"

export type FriendView = {
	UserId: number,
	Name: string,
	Status: FriendStatus,
}

export type HeroView = {
	Id: string,
	Name: string,
	Title: string,
	Role: string,
	Color: Color3,
	IsOwned: boolean,
	CoinPrice: number,
	RobuxPrice: number,
}

export type SkinView = {
	Id: string,
	Name: string,
	HeroName: string,
	-- Main color first.
	Colors: { Color3 },
	RobuxPrice: number,
	IsOwned: boolean,
}

export type LobbyScreenProps = {
	IsOpen: () -> boolean,
	-- The page shown when the lobby first opens.
	StartPage: Page?,
	PlayerName: string | () -> string,
	PlayerUserId: number,
	Coins: () -> number,
	-- Position choices, in the order they are shown.
	Roles: { string },
	-- Nil means Fill: any position.
	PrimaryRole: () -> string?,
	SecondaryRole: () -> string?,
	-- Online friends. Nil while the list loads.
	Friends: () -> { FriendView }?,
	Heroes: () -> { HeroView },
	Skins: () -> { SkinView },
	-- Why Find Match can't be pressed now. Nil when it can.
	FindMatchBlocked: () -> string?,
	-- A short message shown above the bottom edge, such as a failed purchase.
	Notice: () -> string?,
	-- Phones: the friends list moves to its own tab.
	IsCompact: () -> boolean,
	UiScale: () -> number,
	OnSetRole: (slot: RoleSlot, role: string?) -> (),
	OnFindMatch: () -> (),
	-- Opens Roblox's invite prompt, for any friend.
	OnInviteFriends: () -> (),
	OnInvite: (userId: number) -> (),
	OnBuyWithCoins: (itemId: string) -> (),
	OnBuyWithRobux: (itemId: string) -> (),
}

return {}
