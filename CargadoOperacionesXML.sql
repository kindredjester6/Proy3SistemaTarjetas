CREATE PROCEDURE [dbo].[SP_RegistrarOp]
    @inRutaXML NVARCHAR(500),
	@OutResult INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @Datos xml/*Declaramos la variable Datos como un tipo XML*/
		DECLARE @Comando NVARCHAR(500)= 'SELECT @Datos = D FROM OPENROWSET (BULK '  + CHAR(39) + @inRutaXML + CHAR(39) + ', SINGLE_BLOB) AS Datos(D)' -- comando que va a ejecutar el sql dinamico
		DECLARE @Parametros NVARCHAR(500)
		SET @Parametros = N'@Datos xml OUTPUT' --parametros del sql dinamico
		EXECUTE sp_executesql @Comando, @Parametros, @Datos OUTPUT -- ejecutamos el comando que hicimos dinamicamente
		DECLARE @hdoc int /*Creamos hdoc que va a ser un identificador*/
		EXEC sp_xml_preparedocument @hdoc OUTPUT, @Datos/*Toma el identificador y a la variable con el documento y las asocia*/
		BEGIN
			BEGIN TRANSACTION InsercionDatos
				INSERT INTO [dbo].[TarjetaHabiente] 
							([Nombre]
							,[idTipoDocumentoIdentidad]
							,[ValorDocumentoIdentidad]
							,[NombreUsuario]
							,[Password])
				SELECT TH.Nombre, TDI.id, TH.ValorDocumentoIdentidad, TH.NombreUsuario, TH.Password
				FROM OPENXML (@hdoc,  '/root/fechaOperacion/TH/TH' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre',
					idTipoDocumentoIdentidad INT,
					ValorDocumentoIdentidad VARCHAR(100) '@Valor_Doc_Identidad',
					NombreUsuario VARCHAR(100) '@NombreUsuario',
					Password VARCHAR(100) '@Password',
					Tipo_Doc_Identidad VARCHAR(100) '@Tipo_Doc_Identidad'
				)AS TH
				INNER JOIN TipoDocumentoIdentidad AS TDI ON TDI.Nombre = TH.Tipo_Doc_Identidad;

				DECLARE @Codigo INT,
						@FechaCreacion DATE,
						@idTarjetaHabiente INT,
						@idCuentaTarjeta INT, 
						@idTipoCTM INT,
						@LimiteCredito INT,
						@Contador INT,
						@Final INT

				
				DECLARE @TablaTempCTM TABLE 
					(id INT IDENTITY(1,1)
					,Codigo INT
					,idTipoCTM INT
					,LimiteCredito MONEY
					,idTarjeHabien INT)
				INSERT INTO @TablaTempCTM(Codigo, idTipoCTM, LimiteCredito, idTarjeHabien)
				SELECT T.Codigo, TC.id, T.LimiteCredito, TH.id
				FROM OPENXML (@hdoc,  '/root/fechaOperacion/NTCM/NTCM' , 1)
				WITH(
					Codigo INT '@Codigo',
					idTipoCTM INT,
					LimiteCredito MONEY '@LimiteCredito',
					idTarjeHabien INT,
					TipoCTM VARCHAR(100) '@TipoCTM',
					TarjetaHabiente VARCHAR(100) '@TH'
				)AS T
				INNER JOIN TipoCuentaTarjetaMaestra AS TC ON TC.Nombre = T.TipoCTM
				INNER JOIN TarjetaHabiente AS TH ON TH.ValorDocumentoIdentidad = T.TarjetaHabiente
				WHERE EXISTS(SELECT 1 FROM TarjetaHabiente H WHERE H.ValorDocumentoIdentidad = TH.ValorDocumentoIdentidad) 
					AND (EXISTS(SELECT 1 FROM TipoCuentaTarjetaMaestra TM WHERE TM.Nombre = TC.Nombre))

				SELECT @Contador = MAX(A.id) FROM @TablaTempCTM A

				SET @Final = 1
				SET @Contador = @Contador-1;

				WHILE(@Final <= @Contador)
				BEGIN
					SELECT @Codigo = N.Codigo,
						   @idTarjetaHabiente = N.idTarjeHabien,
						   @idTipoCTM = N.idTipoCTM,
						   @LimiteCredito = N.LimiteCredito
					FROM @TablaTempCTM N WHERE N.id = @Final

					SELECT @FechaCreacion = Fecha
					FROM OPENXML(@hDoc, 'root/fechaOperacion', 2)
					WITH (Fecha DATE)

					INSERT INTO [dbo].[CuentaTarjeta]
								([Codigo]
								,[idTCT]
								,[EsMaestra]
								,[FechaCreacion]
								,[idTarjetaHabiente])
					VALUES(@Codigo, 0, 1, @FechaCreacion, @idTarjetaHabiente);
					SET @idCuentaTarjeta = SCOPE_IDENTITY()	--Se obtiene el ultimo valor de identidad de la ultima fila insertada

					INSERT INTO [dbo].[TarjetaCuentaMaestra] 
							([Codigo]
							,[idCuentaTarjeta]
							,[InteresesAcumuladosCorrientes]
							,[InteresesAcumuladosMoratorios]
							,[LimiteCredito]
							,[Saldo]
							,[idTipoCTM])
					VALUES(@Codigo, @idCuentaTarjeta, 0, 0, @LimiteCredito, 0, @idTipoCTM);
					SET @Final = @Final+1
				END;
				
				DECLARE @idTarjetaCuentaMaestra INT

				DECLARE @TablaTempCTA TABLE 
					(id INT IDENTITY(1,1)
					,idTarjetaCuentaMaestra INT
					,Codigo INT
					,idTarjeHabien INT)
				INSERT INTO @TablaTempCTA(idTarjetaCuentaMaestra, Codigo, idTarjeHabien)
				SELECT TM.id, T.Codigo, TH.id
				FROM OPENXML (@hdoc,  '/root/fechaOperacion/NTCA/NTCA' , 1)
				WITH(
					idTarjetaCuentaMaestra INT,
					Codigo INT '@CodigoTCA',
					idTarjeHabien INT,
					CodigoTCM INT '@CodigoTCM',
					TarjetaHabiente VARCHAR(100) '@TH'
				)AS T
				INNER JOIN TarjetaCuentaMaestra AS TM ON TM.Codigo = T.CodigoTCM
				INNER JOIN TarjetaHabiente AS TH ON TH.ValorDocumentoIdentidad = T.TarjetaHabiente
				WHERE EXISTS(SELECT 1 FROM TarjetaHabiente H WHERE H.ValorDocumentoIdentidad = TH.ValorDocumentoIdentidad) 
					AND (EXISTS(SELECT 1 FROM TarjetaCuentaMaestra TN WHERE TN.Codigo = TM.Codigo))

				SELECT @Contador = MAX(A.id) FROM @TablaTempCTA A

				SET @Final = 1

				WHILE(@Final <= @Contador)
				BEGIN
					SELECT @Codigo = N.Codigo,
						   @idTarjetaHabiente = N.idTarjeHabien,
						   @idTarjetaCuentaMaestra = N.idTarjetaCuentaMaestra
					FROM @TablaTempCTA N WHERE N.id = @Final

					INSERT INTO [dbo].[CuentaTarjeta]
								([Codigo]
								,[idTCT]
								,[EsMaestra]
								,[FechaCreacion]
								,[idTarjetaHabiente])
					VALUES(@Codigo, 0, 0, @FechaCreacion, @idTarjetaHabiente);
					SET @idCuentaTarjeta = SCOPE_IDENTITY()	--Se obtiene el ultimo valor de identidad de la ultima fila insertada

					INSERT INTO [dbo].[TarjetaCreditoAdicional] 
							([Codigo]
							,[idTCM]
							,[idCuentaTarjeta])
					VALUES(@Codigo, @idTarjetaCuentaMaestra, @idCuentaTarjeta);
					SET @Final = @Final+1
				END;				

				INSERT INTO [dbo].[TarjetaFisica] 
							([CCV]
							,[Codigo]
							,[FechaInvalidacion]
							,[idMotivoInvalidacion]
							,[FechaCreacion]
							,[FechaVencimiento]					
							,[idCuentaTarjeta]
							,[idTCAsociada])
				SELECT TF.CCV, TF.Codigo, TF.FechaInvalidacion, TF.idMotivoInvalidacion, @FechaCreacion AS FechaCreacion, TF.FechaVencimiento, TF.idCuentaTarjeta, TCA.id
				FROM OPENXML (@hdoc,  '/root/fechaOperacion/NTF/NTF' , 1)
				WITH(
					CCV INT 'CCV',
					Codigo INT 'Codigo',
					FechaInvalidacion Date, 
					idMotivoInvalidacion INT, 
					FechaCreacion DATE, 
					FechaVencimiento VARCHAR(100) 'FechaVencimiento', 
					idCuentaTarjeta INT,
					idTCAsociada INT,
					TCAsociada INT 'TCAsociada'
				)AS TF
				INNER JOIN TarjetaCreditoAdicional AS TCA ON TCA.Codigo = TF.TCAsociada

				INSERT INTO [dbo].[Movimiento] 
							([Nombre]
							,[idTarjetaFisica]
							,[FechaMovimiento]
							,[Monto]
							,[Descripcion]
							,[Referencia]
							,[idTipoMovimiento]
							,[idEstadoCuenta])
				SELECT M.Nombre, TF.id, M.FechaMovimiento, M.Monto, M.Descripcion, M.Referencia, TM.id, idEstadoCuenta
				FROM OPENXML (@hdoc,  '/root/fechaOperacion/Movimiento/Movimiento' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre',
					TarjeFisica INT '@TF',
					FechaMovimiento DATE '@FechaMovimiento',
					Monto INT '@Monto',
					Descripcion VARCHAR(100) 'Descripcion',
					Referencia VARCHAR(100) '@Referencia',
					idTarjetaFisica INT,
					idTipoMovimiento INT, 
					idEstadoCuenta INT
				)AS M
				INNER JOIN TarjetaFisica AS TF ON TF.Codigo = M.TarjeFisica
				INNER JOIN TipoMovimiento AS TM ON TM.Nombre = M.Nombre

				
				EXEC sp_xml_removedocument @hdoc/*Remueve el documento XML de la memoria*/
				SET NOCOUNT OFF;
			COMMIT TRANSACTION
		END;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION InsercionDatos
		END 
		INSERT INTO dbo.DBErrors
			(
			[UserName]
			,[ErrorNumber]
			,[ErrorState]
			,[ErrorSeverity]
			,[ErrorLine]
			,[ErrorProcedure]
			,[ErrorMessage]
			,[ErrorDateTime]
			)
			VALUES 
			(
			SUSER_SNAME()
			, ERROR_NUMBER()
			, ERROR_STATE()
			, ERROR_SEVERITY()
			, ERROR_LINE()
			, ERROR_PROCEDURE()
			, ERROR_MESSAGE()
			, GETDATE()
			);
			SET @OutResult =500001
	END CATCH
END;
