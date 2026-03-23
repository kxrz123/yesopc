package handler

import (
	"net/http"

	"yesopc.com/services/content-api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

func RegisterRoutes(server *rest.Server, ctx *svc.ServiceContext) {
	server.AddRoutes([]rest.Route{
		{
			Method:  http.MethodGet,
			Path:    "/",
			Handler: RootHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/health",
			Handler: HealthHandler(),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/auth/register",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/auth/register",
			Handler: RegisterHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/auth/login",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/auth/login",
			Handler: LoginHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/auth/logout",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/auth/logout",
			Handler: LogoutHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/auth/me",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/auth/me",
			Handler: MeHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/notes",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/notes",
			Handler: ListNotesHandler(ctx),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/notes",
			Handler: CreateNoteHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/articles",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/articles",
			Handler: ListArticlesHandler(ctx),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/articles",
			Handler: CreateArticleHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/favorites/status",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/users/profile",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/users/profile",
			Handler: UserProfileHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/follows/status",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/follows/status",
			Handler: FollowStatusHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/follows",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/follows",
			Handler: ListFollowingHandler(ctx),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/follows",
			Handler: AddFollowHandler(ctx),
		},
		{
			Method:  http.MethodDelete,
			Path:    "/api/v1/follows",
			Handler: RemoveFollowHandler(ctx),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/favorites/status",
			Handler: FavoriteStatusHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/favorites",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/favorites",
			Handler: ListFavoritesHandler(ctx),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/favorites",
			Handler: AddFavoriteHandler(ctx),
		},
		{
			Method:  http.MethodDelete,
			Path:    "/api/v1/favorites",
			Handler: RemoveFavoriteHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/tags",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/api/v1/tags",
			Handler: ListTagsHandler(ctx),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/tags",
			Handler: CreateTagHandler(ctx),
		},
		{
			Method:  http.MethodOptions,
			Path:    "/api/v1/upload",
			Handler: OptionsHandler(),
		},
		{
			Method:  http.MethodPost,
			Path:    "/api/v1/upload",
			Handler: UploadHandler(ctx),
		},
	})
}
