CREATE TABLE [dbo].[TablaEstadosCuenta](
	[idCT] [int] IDENTITY(1,1) NOT NULL,
	[SaldoActual] [int] NULL,
	[SaldoInteresesMoratorios] [int] NULL,
	[FechaOperacion] [datetime] NULL,
	[FechaParaPagoMinimoDeContado] [datetime] NULL,
	[MontoPagoMinimoMoratorio] [int] NULL,
	[SumaDePagos] [int] NULL,
	[TasaInteresMoratorios] [int] NULL,
	[MontoDebitoInteresesMoratorios] [int] NULL
	CONSTRAINT [PK_CTM] PRIMARY KEY CLUSTERED 
	(
		[idCT] ASC
	) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE PROCEDURE CalculoInteresesMoratoriosSobrePagoMínimoIncumplido
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE TablaEstadosCuenta

	SET MontoPagoMinimoMoratorio = MontoPagoMinimoMoratorio - SumaDePagos,
		MontoDebitoInteresesMoratorios = MontoDebitoInteresesMoratorios / (TasaInteresMoratorios / 100 / 30),
		SaldoInteresesMoratorios = SaldoInteresesMoratorios + MontoDebitoInteresesMoratorios,
		SaldoActual = SaldoActual + SaldoInteresesMoratorios,
		SaldoInteresesMoratorios = 0
	WHERE FechaOperacion > FechaParaPagoMinimoDeContado AND SumaDePagos < MontoPagoMinimoMoratorio
		
	SET NOCOUNT OFF;
END;