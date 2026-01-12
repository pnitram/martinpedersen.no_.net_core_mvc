FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy AS base
WORKDIR /app
EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000

RUN useradd -u 5678 -m appuser && chown -R appuser /app
USER appuser

FROM mcr.microsoft.com/dotnet/sdk:8.0-jammy AS build
WORKDIR /src
COPY ["martinpedersen.no.csproj", "./"]
RUN dotnet restore "martinpedersen.no.csproj"
COPY . .
RUN dotnet publish "martinpedersen.no.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "martinpedersen.no.dll"]

